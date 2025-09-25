package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file register-ecom.lua
 @brief register ETM with E.COM

--]]
require "common"

local env = ...

LOG("register-ecom")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0}
local req = req.etm

if ((req.admin == nil) or (req.admin.username == nil) or (req.admin.password == nil)) then
    response.err = 1
    response.msg = "Invalid username or password"
    response.msgkey = "ETM.cgi.invalid_auth"
end

if (req.operation.agency_domain == nil) then
    response.err = 1
    response.msg = "No domain specified"
    response.msgkey = "ETM.cgi.invalid_domain"
end

-- If the current local domain is set, we still try again, since there are cases where the
-- Dock mishandled failure and might not really be registered at the server (DOCK-917)

if (response.err ~= 0) then
    LOG(response.msg)
    send(json.encode(response))
    return
end

domain = req.operation.agency_domain
LOG(req.admin.username .. "@" .. domain)

if (endsWith(domain, ".evidence.com") == false) then
    domain = domain .. ".evidence.com"
end

local auth = "echo $'".. esc_ansi_cstr(req.admin.username) .. ":" .. esc_ansi_cstr(req.admin.password) .. "' | "
local cmd ="/usr/bin/sudo /www/scripts/register-ecom.sh " .. sanitize_input(domain, true)
LOG(cmd)
local file = io.popen(auth .. cmd, "r")
-- "*a" - reads the whole file starting at the current position;
-- on the end of file it returns an empty string
local output = file:read("*a")
file:close()
local l = lines(output)
response.msg = l[#l]
LOG(response.msg)

if (response.msg:find("DONE:register%-ecom%.sh") == 1) then
    response.err = 0
elseif (response.msg:find("ERR:") == 1) then
    response.err, response.msg = response.msg:match("(%d+)/([^/]*)")
    -- BWE-287: For consistent and easier to understand error message, the 100006 "SSL handshake failed" is change to 1060
    if ((response.err == "100006") or (response.err == "1060")) then
        response.err = "1060"
        response.msg = domain
    end
else
    response.err = 2
    response.msg = "Unknown error"
    response.msgkey = "ETM.cgi.unknown_err"
end

send(json.encode(response))
