--[[

 Copyright (c) 2020 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file update-ecom.lua
 @brief Get updates from Agency for the device, return a JSON reply.

--]]

require "common"
require "lib.json"

local env = ...

LOG("update-ecom")
send_header(env)

local file = io.popen("/usr/bin/sudo /www/scripts/ecom.sh get-device-info", "r")
local output = file:read("*all"):gsub("^%s+", ""):gsub("%s+$", "")
file:close()

if output == "" then
    send(json.encode({err = 1}))
else
    local info = json.decode(output:gsub("%[%]", "%[null%]"))

    local response = {err=0, etm={etm={device_home="none"}}}

    if info.data.attributes.friendlyName then
        response.etm.etm.name = info.data.attributes.friendlyName
    end

    if info.included then
        for _, v in ipairs(info.included) do
            if v.type == "deviceHome" then
                response.etm.etm.device_home = v.attributes.name
            end
        end
    end

    send(json.encode(response))
end
