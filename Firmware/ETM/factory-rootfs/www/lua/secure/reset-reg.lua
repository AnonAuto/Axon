package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
  --[[

   Copyright (c) 2014 TASER International, Inc.
   All Rights Reserved
   TASER Data Classification: CONFIDENTIAL

   @file reset-reg.lua
   @brief Reset registration of Dock to default

--]]

require "common"

local env = ...

LOG("Event=reset-reg")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

local response = {err = 0, msg = "OK"}
send(json.encode(response))

LOG("Event=SchedulingRegistrationReset")
set_webui_req("reset-reg")
