--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL
 
 @file get-blobs.lua
 @brief query dock support blobs and return them in a JSON reply.
 
--]]
require "common"
require "lib.structs"

local env = ...

function readFile(filename)
    local response = {}
   
    file, err = io.open(filename, 'r')
    if (file == nil) then
        response = {err = 1, msg = err}
    else 
        response = {err = 0, data =""}
        response.data = file:read('*all')
        file:close()
    end
    return response
end


LOG("get-blobs")
send_header(env)

response = {err = 0}

local file1 = "/etc/config/challenge.txt"
local file2 = "/etc/config/challenge.txt.prev1"

data1 = readFile(file1)
data2 = readFile(file2)

response = {err = 0}                

if (data1.err == 0) then
    response.blob1 = data1.data
else
    LOG("get-blobs - error blob1" .. data1.msg)
end

if (data2.err == 0) then
    response.blob2 = data2.data
else
    LOG("get-blobs - error blob2" .. data2.msg)
end

send(json.encode(response))

