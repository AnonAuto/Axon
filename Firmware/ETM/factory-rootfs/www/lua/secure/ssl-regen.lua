package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file ssl-regen.lua
 @brief Trigger generation of the Dock's self-signed SSL cert

--]]
require "common"

local env = ...

LOG("ssl-regen")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0, msg = "OK"}
send(json.encode(response))

LOG("Scheduling re-generation of certificates for HTTPS")
set_webui_req("ssl-regen")

