package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file etm-restart.lua
 @brief restart ETMD, called by webUI after registering.
 
--]]
require "common"

local env = ...

LOG("etm-restart")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0, msg = "OK"}
send(json.encode(response))

LOG("Scheduling restart of etmd")
set_webui_req("etm")
