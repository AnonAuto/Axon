package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[ 

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file get-keys.lua 
 @brief Register ETM with E.Com and update the authentication keys

--]]
require "common"

local env = ...

LOG("get-keys")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

response = {err = 0}
local req = req.etm

if ((req.admin == nil) or (req.admin.username == nil) or (req.admin.password == nil)) then
    response.err = 1
    response.msg = "Invalid username or password"
    response.msgkey = "ETM.cgi.invalid_auth"
end

if (response.err ~= 0) then
    LOG(response.msg)
    send(json.encode(response))
    return
end

local auth = "echo $'".. esc_ansi_cstr(req.admin.username) .. ":" .. esc_ansi_cstr(req.admin.password) .. "' | "
local cmd = "/usr/bin/sudo /www/scripts/get-keys-ecom.sh"
LOG(cmd)
local file = io.popen(auth .. cmd, "r")
local output = file:read("*a")
file:close()
local l = lines(output)
response.msg = l[#l]
LOG(response.msg)

if (response.msg:find("DONE:get%-keys%-ecom%.sh") == 1) then
    response.err = 0
elseif (response.msg:find("ERR:") == 1) then
    response.err, response.msg = response.msg:match("(%d+)/([^/]*)")
else
    response.err = 2
    response.msg = "Unknown error"
    response.msgkey = "ETM.cgi.unknown_err"
end

if (response.err == 0) then
    -- initiate password update
    response = gen_password()
end

send(json.encode(response))
