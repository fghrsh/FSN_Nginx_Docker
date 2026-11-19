-- Author: Alexa (AlexaZhou@163.com)
local VeryNginxConfig = require "VeryNginxConfig"
local dkjson = require "dkjson"

local _M = {}
local seed

function _M.get_seed()
    if seed then
        return seed
    end

    local path = VeryNginxConfig.home_path() .. "/configs/encrypt_seed.json"
    local file = io.open(path, "r")
    if file then
        local saved = dkjson.decode(file:read("*a"))
        file:close()
        assert(saved and type(saved.encrypt_seed) == "string" and saved.encrypt_seed ~= "",
               "invalid VeryNginx session seed")
        seed = saved.encrypt_seed
        return seed
    end

    local random = assert(io.open("/dev/urandom", "rb"))
    local bytes = random:read(32)
    random:close()
    assert(bytes and #bytes == 32, "could not read VeryNginx session seed")
    seed = ngx.encode_base64(bytes)

    local tmp = path .. ".tmp"
    file = io.open(tmp, "w")
    if file then
        assert(file:write(dkjson.encode({ encrypt_seed = seed })))
        assert(file:close())
        assert(os.rename(tmp, path))
    else
        ngx.log(ngx.WARN, "could not persist VeryNginx session seed")
    end
    return seed
end

return _M
