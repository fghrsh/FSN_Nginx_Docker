local VeryNginxConfig = require "VeryNginxConfig" 
-- Load the session seed once before nginx forks its workers.
require("encrypt_seed").get_seed()

local status = require "status"
status.init()
