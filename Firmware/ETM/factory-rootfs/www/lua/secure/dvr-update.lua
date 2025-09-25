package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file dvr-update.lua
 @brief Trigger Firmware update for devices
 
--]]
require "common"

local env = ...

LOG("dvr-update")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0, msg = "OK"}
send(json.encode(response))

LOG("Scheduling DVR firmware update")
set_webui_req("dvr-fw-update")
