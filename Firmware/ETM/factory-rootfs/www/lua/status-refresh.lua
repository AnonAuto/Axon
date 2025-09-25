--[[ 

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file status-refresh.lua
 @brief Trigger status refresh via CGI

--]]
require "common"

local env = ...

LOG("status-refresh")
send_header(env)

local response = {err = 0, msg = "OK"}
syscall_exec("/usr/bin/sudo /etm/bin/etmstat.sh -n > /dev/null 2>&1")

send(json.encode(response))
