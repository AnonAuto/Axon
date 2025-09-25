--[[

 Copyright (c) 2020 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file get-device-homes.lua
 @brief query the list of device home available on Agency, return a JSON reply.

--]]

require "common"
require "lib.json"

local env = ...

LOG("get-device-homes")
send_header(env)

local file = io.popen("/usr/bin/sudo /www/scripts/ecom.sh get-device-homes", "r")
local output = file:read("*all"):gsub("^%s+", ""):gsub("%s+$", "")
file:close()

if output == "" then
    send(json.encode({err = 1}))
else
    local info = json.decode(output:gsub("%[%]", "%[null%]"))
    local response = {err = 0, homes = {}}
    if info.data then
        for _, v in ipairs(info.data) do
            if v.type == "deviceHome" then
                table.insert(response.homes, {name=v.attributes.name, id=v.id})
            end
        end
    end
    send(json.encode(response))
end
