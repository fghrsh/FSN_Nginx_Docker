# Alpine 3.23's musl can write the PID file on older Docker hosts that deny pwritev2.
FROM alpine:3.23 AS base

FROM base AS builder

ARG NGINX_VERSION=1.31.9
ARG OPENRESTY_VERSION=1.31.8.1
WORKDIR /usr/src

RUN apk add --no-cache build-base linux-headers patch curl brotli-dev gd-dev geoip-dev \
        libxslt-dev openssl-dev pcre2-dev zlib-dev zstd-dev

# Use OpenResty's matching Lua modules and LuaJIT with the nginx.org core.
RUN set -eu; \
    fetch() { curl -fsSL --retry 3 "$2" -o "$1"; echo "$3  $1" | sha256sum -c -; }; \
    fetch nginx.tgz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
        a11c5eeee2e257f4478f0e649f84b0040787d277d2d3e5233952aa6b6dcb80ad; \
    fetch openresty.tgz "https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz" \
        b569c63b420f80a4ac8466f2deffe73ed93ab760026532e039c3658409a997f4; \
    fetch brotli.tgz https://codeload.github.com/GetPageSpeed/ngx_brotli/tar.gz/8b0103778e3dce455f4aeb2aa546d9501add79f3 \
        3f1f32d15747416d9b6a775734f0ecad9ab64a09540e474d8a737b652832edc2; \
    fetch zstd.tgz https://codeload.github.com/GetPageSpeed/zstd-nginx-module/tar.gz/4a0019c89b18ed7a6d27967aab9c3a26f566788b \
        35f0142c14c0ed8b416080fec2af273e596f71c33ae54af0ca8e2b80f8f84689; \
    fetch dyn-records.patch https://raw.githubusercontent.com/kn007/patch/a9b34bb34e3168813371851ce860d14c9f73546a/nginx_dynamic_tls_records.patch \
        9d43c92b6925aa6f926698630e89ea2caa06e15d911e068c75cb0d713c46ba51; \
    for dir in nginx openresty brotli zstd; do \
        mkdir "$dir"; tar -xzf "$dir.tgz" --strip-components=1 -C "$dir"; \
    done

WORKDIR /usr/src/openresty/bundle
RUN make -C LuaJIT-* -j4 && make -C LuaJIT-* install \
    && make -C lua-resty-core-* install LUA_LIB_DIR=/usr/local/share/lua/5.1 \
    && make -C lua-resty-lrucache-* install LUA_LIB_DIR=/usr/local/share/lua/5.1

WORKDIR /usr/src/nginx
COPY patches/ /usr/src/patches/
RUN set -eu; \
    patch -p1 < ../dyn-records.patch; \
    patch -p1 < ../patches/verynginx.patch; \
    patch -d /usr/src -p1 < ../patches/content-coding.patch; \
    LUAJIT_LIB=/usr/local/lib LUAJIT_INC=/usr/local/include/luajit-2.1 ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx --group=nginx \
        --with-http_ssl_module --with-http_v2_module --with-http_v3_module \
        --with-http_realip_module --with-http_addition_module --with-http_sub_module \
        --with-http_dav_module --with-http_flv_module --with-http_mp4_module \
        --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module \
        --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module \
        --with-http_xslt_module --with-http_image_filter_module --with-http_geoip_module --with-http_slice_module \
        --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-stream_realip_module --with-stream_geoip_module \
        --with-mail --with-mail_ssl_module --with-threads --with-compat --with-file-aio \
        --with-cc-opt=-I/usr/src/zstd \
        --add-module=../brotli --add-module=../zstd \
        --add-module=../openresty/bundle/headers-more-nginx-module-0.40 \
        --add-module=../openresty/bundle/ngx_devel_kit-0.3.6 \
        --add-module=../openresty/bundle/ngx_lua-0.10.32rc7; \
    make -j4; make install; strip /usr/sbin/nginx; \
    mkdir -p /usr/share/nginx /etc/nginx/conf.d; \
    mv /etc/nginx/html /usr/share/nginx/html; \
    ln -s ../../usr/lib/nginx/modules /etc/nginx/modules

FROM base
LABEL maintainer="FGHRSH <fghrsh@wxw.moe>"

RUN apk add --no-cache brotli-libs libgd geoip libxslt libssl3 pcre2 zlib zstd-libs \
        gettext-envsubst tzdata logrotate \
    && ln -s /usr/bin/envsubst /usr/local/bin/envsubst \
    && delgroup www-data \
    && addgroup -g 82 -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -u 82 -G nginx nginx \
    && mkdir -p /var/log/nginx \
    && ln -s /dev/stdout /var/log/nginx/access.log \
    && ln -s /dev/stderr /var/log/nginx/error.log \
    && echo '1 0 * * * /usr/sbin/logrotate /etc/logrotate.conf -f' > /etc/crontabs/root

COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/share/nginx /usr/share/nginx
COPY --from=builder /usr/local/lib/libluajit-5.1.so.2 /usr/local/lib/libluajit-5.1.so.2
COPY --from=builder /usr/local/share/luajit-2.1 /usr/local/share/luajit-2.1
COPY --from=builder /usr/local/share/lua/5.1 /usr/local/share/lua/5.1
COPY conf/ /etc/nginx/
COPY verynginx/ /opt/verynginx/
RUN mv /etc/nginx/logrotate /etc/logrotate.d/nginx \
    && chgrp nginx /opt/verynginx/configs && chmod 750 /opt/verynginx/configs \
    && chown nginx:nginx /opt/verynginx/configs/config.json \
    && nginx -t && test ! -e /opt/verynginx/configs/encrypt_seed.json

EXPOSE 80 443 443/udp
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
