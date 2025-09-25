--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file get-status.lua
 @brief get device status information. Hides secured information.
 
--]]
require "common"

--hide secure information on get status call
get_status(false, ...);

