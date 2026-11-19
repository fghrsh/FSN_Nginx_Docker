#!/bin/sh
# Pass the URL of a compressible static file of at least 256 bytes.
set -eu
url=${1:?usage: sh tests/compression.sh URL}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsS -H 'Accept-Encoding: identity' "$url" -o "$tmp/plain"
check() {
    offered=$1
    expected=$2
    shift 2
    curl -fsS --compressed -H "Accept-Encoding: $offered" "$@" -D "$tmp/headers" "$url" -o "$tmp/body"
    actual=$(awk 'tolower($1) == "content-encoding:" {sub(/\r$/, "", $2); print $2}' "$tmp/headers")
    grep -iq '^vary:.*accept-encoding' "$tmp/headers"
    if [ "$actual" != "$expected" ]; then
        echo "Accept-Encoding '$offered $*': expected '${expected:-identity}', got '${actual:-identity}'" >&2
        exit 1
    fi
    cmp "$tmp/plain" "$tmp/body"
}

check 'gzip, br, zstd' zstd
check 'zstd, br, gzip' zstd
check 'gzip;q=1, br;q=0.8, zstd;q=0.1' zstd
check 'gzip, br' br
check 'gzip;q=1, br;q=0.5' br
check 'gzip' gzip
check 'br' br
check 'zstd' zstd
check 'gzip, zstd;q=0, br' br
check 'br;q=0, gzip, zstd;q=0.000' gzip
check 'gzip;q=0, br;q=0, zstd;q=0' ''
check 'x-zstd, x-br, x-gzip-test' ''
check '*' zstd
check '*, zstd;q=0' br
check '*, zstd;q=0, br;q=0' gzip
check '*;q=0' ''
check 'gzip' zstd -H 'Accept-Encoding: br, zstd'
check '*' br -H 'Accept-Encoding: ZSTD;Q=0'
check 'deflate' ''
check 'identity' ''
check '' ''
