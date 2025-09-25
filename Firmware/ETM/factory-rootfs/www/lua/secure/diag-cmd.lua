package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file diag-cmd.lua
 @brief run network diagnostic commands from the diag webUI page
 
--]]

require "common"

local env = ...

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

cmd = {}
cmd["date"] = "/bin/date"
cmd["ping-8"] = "/bin/ping -c 5 -w 30 8.8.8.8"
cmd["ping-goog"] = "/bin/ping -c 5 -w 30 google.com"
cmd["tr-goog"] = "/usr/bin/traceroute google.com"
cmd["tr-taser"] = "/usr/bin/traceroute taser.evidence.com"
-- following commands require root permissions
--cmd["ifconfig"] = "/sbin/ifconfig"
--cmd["tail-sys"] = "/usr/bin/tail -100 /root/log/syslog"
--cmd["tail-etm"] = "/usr/bin/tail -100 /root/log/etmd.log"
--cmd["ping-gw"] = "GW=`/sbin/uci -P /var/state get network.wan.gateway`; /bin/ping -c 5 -w 30 $GW"
--cmd["dns-taser"] = "/usr/bin/nslookup taser.evidence.com"
--cmd["dns-goog"] = "/usr/bin/nslookup google.com"

response = {err = 0}
cmd_str = cmd[req.cmd]    

if (cmd_str ~= nil) then
    LOG("diag: " .. cmd_str)
    local file = io.popen(cmd_str, "r")
    local output = file:read("*a")
    file:close()
    response.msg = output
    -- LOG(response.msg)
else 
    response.err = 1
    response.msg = "Invalid command"
    response.msgkey = "ETM.cgi.invalid_cmd"
end

send(json.encode(response))
