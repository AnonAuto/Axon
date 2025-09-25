--[[

 Copyright (c) 2023 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file get-login-uri-code.lua
 @brief get the user_code, verification_uri and other information from device_authorization_endpoint

--]]

require "common"
require "lib.json"

local env = ...

LOG("get-login-uri-code")
local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0}
local file = io.popen("/usr/bin/sudo /www/scripts/get-login-uri-code.sh ", "r")
local output = file:read("*a")
file:close()
local l = lines(output)
local last = l[#l]

if (last:find("DONE:get%-login%-uri%-code%.sh") == 1) then
    response.err = 0
    response.verification_uri = l[1]
    response.user_code = l[2]
    response.interval = l[3]
elseif (last:find("ERR:") == 1) then
    response.err, response.msg = last:match("(%d+)/([^/]*)")
else
    response.err = 2
    response.msg = "Unknown error"
    response.msgkey = "ETM.cgi.unknown_err"
end

send(json.encode(response))
