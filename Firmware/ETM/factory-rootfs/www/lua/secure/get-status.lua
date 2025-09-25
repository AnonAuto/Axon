package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
require "common"

--[[

 Copyright (c) 2015 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file get-status.lua
 @brief get device status information. Shows secured information.
 
]]--

--show secure information on get status call
get_status(true, ...);

