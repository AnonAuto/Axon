--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file get-config.lua
 @brief query etm & network configuration.  return a JSON reply.

--]]

require "common"

local env = ...

LOG("get-config")
send_header(env)

local response = {err = 0, etm={ etm={}, operation={}, firmware={}, early_access_firmware={}, proxy={} }}
local cmd ="/usr/bin/sudo /www/scripts/get-uci-cfg.sh"
response = transform_configuration(cmd, response)

-- only report early access firmware when it is different than the regular released firmware.
-- so go through each item, compare and update as necessary.
for k,v in pairs(response.etm.early_access_firmware) do
    if(response.etm.firmware[k] != nil and response.etm.firmware[k] == v) then
        response.etm.early_access_firmware[k] = "Not released"
    end
end

-- Slight hack.
-- This function converts data from the storage format to the UI format.
convertForUI(response.etm);

-- networking ( read /etc/networking/interfaces )
response.network = {wan = {}}
local r, l = syscall("/usr/bin/awk -f /etm/bin/queryInterfaces.awk /etc/network/interfaces device=" .. WAN_IFACE, "r");
if (r.err == 0) then
    -- process lines
    for _,v in ipairs(l) do
        parts = split(v, ' ');
        -- dns is a special case of an array
        if (parts[1] == "dns" ) then
            response.network.wan.dns = {};
            for i = 2, #parts do
                table.insert(response.network.wan.dns, parts[i]);
            end
        else
            response.network.wan[parts[1]]=parts[2];
        end
    end
end

send(json.encode(response))
