--[[

 Copyright (c) 2017 Axon Enterprise, Inc.
 All Rights Reserved
 Axon Data Classification: CONFIDENTIAL

 @file get-header.lua
 @brief return the web UI header information that is common to most pages.

--]]

require "common"

local env = ...

LOG("get-header")
send_header(env)

local cmd ="/usr/bin/sudo /www/scripts/get-header.sh"
local response = transform_configuration(cmd, {err = 0, etm={ etm={} }})

send(json.encode(response))
