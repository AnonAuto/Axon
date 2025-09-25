--[[

 Copyright (c) 2023 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file get-login-configuration.lua
 @brief query login configurations of Agency, return a JSON reply.

--]]

require "common"
require "lib.json"

local env = ...

LOG("get-login-configuration-ecom")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0}
local req = req.etm

if (req.operation.agency_domain == nil) then
    response.err = 1
    response.msg = "No domain specified"
    response.msgkey = "ETM.cgi.invalid_domain"
    LOG(response.msg)
    send(json.encode(response))
    return
end

local domain = req.operation.agency_domain
if (endsWith(domain, ".evidence.com") == false) then
    domain = domain .. ".evidence.com"
end

local file = io.popen("/usr/bin/sudo /www/scripts/get-login-configuration-ecom.sh " .. sanitize_input(domain, true), "r")
local output = file:read("*a")
file:close()
local l = lines(output)
local last = l[#l]

if (last:find("ERR:") == 1) then
    response.err, response.msg = last:match("(-?%d+)/([^/]*)")
else
    response.err = 2
    response.msg = "Unknown error"
    response.msgkey = "ETM.cgi.unknown_err"
end

send(json.encode(response))
