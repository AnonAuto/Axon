package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2023 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file register-ecom-universal-login.lua
 @brief register ETM with E.COM in the universal login flow

--]]
require "os"
require "common"

local env = ...
LOG("register-ecom-universal-login")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

-- Server sluggish that return inconsistent result (10000:Authentication required) https://taserintl.atlassian.net/browse/EMUX-3560
-- Until the server side is fix, Dock implements retry
-- 5 is chosen because as observed, the largest retries required is 4 while mostly requires 1 to 2 retries.
local response = {err = 10000} 
local retries = 0

while (tostring(response.err) == "10000") and (retries <= 5) do
    response.msg = ""
    response.msgkey = ""
    local cmd ="/usr/bin/sudo /www/scripts/register-ecom-universal-login.sh"
    LOG(cmd .. " retries=" .. retries)
    local file = io.popen(cmd, "r")
    -- "*a" - reads the whole file starting at the current position;
    -- on the end of file it returns an empty string
    local output = file:read("*a")
    file:close()
    local l = lines(output)
    response.msg = l[#l]
    LOG(response.msg)

    if (response.msg:find("DONE:register%-ecom%-universal%-login%.sh") == 1) then
        response.err = 0
    elseif (response.msg:find("ERR:") == 1) then
        response.err, response.msg = response.msg:match("(%d+)/([^/]*)")
    else
        response.err = 2
        response.msg = "Unknown error"
        response.msgkey = "ETM.cgi.unknown_err"
    end
    retries = retries + 1
end

if (response.err == 0) then
    -- initiate password update
    response = gen_password()
end

send(json.encode(response))
