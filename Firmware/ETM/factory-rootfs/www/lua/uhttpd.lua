#!/usr/bin/lua
package.path = package.path .. ";/www/lua/?.lua"
package.cpath = package.cpath .. ";/usr/lib/lua-?.so"

--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file uhttpd.lua
 @brief Lua CGI wrapper

This wrapper is pure LUA, so it doesn't require a custom add-in module for the webserver.
This is roughly equivalent to what uhttpd's lua plugin did in C, but does it only in LUA so is portable
across web servers.  The configuration of the web server should execute lua CGI scripts by executing this
script and passing the name of the desired script as an input parameter.
--]]

require "lib.json"
require "uci"
require "os"
require "common"

-- Create the global CGI evironment object
cgi={}

DEBUG=nil

_G["ERR_NO_ERROR"]   = {err = 0, msg = "OK", msgkey = "ETM.cgi.ok"}
_G["ERR_CSRF_ERROR"] = {err = 1, msg = "Cookie Error", msgkey = "ETM.cgi.csrf_fail"}
_G["ERR_NO_CONTENT"] = {err = 1, msg = "No content", msgkey = "ETM.cgi.no_content"}
_G["WAN_IFACE"]      = 'eth1'

_G["clean"] = function(s)
    if (s == nil) then return "" end
    return s
end

_G["recv"] = function(env)
    if (cgi.CONTENT_READ == nil) then
        cgi.CONTENT_READ = cgi.CONTENT_LENGTH
    end
    local len = cgi.CONTENT_READ

    if len > 0 then
        local rbuf = io.stdin:read(4096)
        local rlen = 0
        if (rbuf == nil) then
            rlen = 0
        else
            rlen = string.len(rbuf);
        end
        if rlen >= 0 then
            cgi.CONTENT_READ = len - rlen
            return rbuf
        end
    end
    return nil
end

_G["send"] = function(...)
    local var=...
    if (type(var) == "table") then
        for i,p in pairs(var) do
            io.stdout:write(clean(i)..clean(p))
        end
    elseif (type(var) ~= "nil") then
        io.stdout:write(var);
    end
--  io.stdout:write("\r\n");
end

_G["LOG"] = function(msg)
    -- make suspicious characters visible in the log (hack detection)
    if (type(msg) ~= "nil") then
        msg = msg:gsub("`","BTICK")
        msg = msg:gsub('"',"DQUOTE")
        msg = msg:gsub("'","SQUOTE")
        msg = msg:gsub("%$","DSIGN")
        msg = msg:gsub("%|","PIPE")
    else
        msg = "nil"
    end
    -- oddly logger will look inside a quoted parameter and try to treat it as
    -- a switch and generate an error, so if the first character is a hyphen, just
    -- make it a .
    if (string.sub(msg,1,1) == "-") then
       msg = '.' .. msg
    end

    os.execute("/usr/bin/sudo /usr/bin/logger -p daemon.info -t 'etm-www' '".. msg .."'")
end

--[[
function handle_request(env)
    env.CONTENT_LENGTH = env.CONTENT_LENGTH or 0
    local fn = assert(loadfile("/www/lua/" .. env.PATH_INFO:sub(2) .. ".lua"))
    fn(env)
end
--]]

-- Populate the CGI environment object
local properties = {"CONTENT_LENGTH",
                    "DOCUMENT_ROOT",
                    "GATEWAY_INTERFACE",
                    "HTTP_ACCEPT",
                    "HTTP_ACCEPT_ENCODING",
                    "HTTP_ACCEPT_LANGUAGE",
                    "HTTP_CONNECTION",
                    "HTTP_HOST",
                    "HTTP_COOKIE",
                    "HTTP_USER_AGENT",
                    "REDIRECT_STATUS",
                    "REMOTE_ADDR",
                    "REMOTE_PORT",
                    "REQUEST_METHOD",
                    "REQUEST_URI",
                    "SCRIPT_FILENAME",
                    "SCRIPT_NAME",
                    "SERVER_ADDR",
                    "SERVER_NAME",
                    "SERVER_PORT",
                    "SERVER_PROTOCOL",
                    "SERVER_SOFTWARE" }


if DEBUG then
    -- dump entire environment for debugging
    print("Environment:")
    local file = io.popen("set", "r")
    local msg = "";
    local count = 1
    while true do
      local line = file:read()
      if line == nil then break end
      msg = msg .. line
      print(string.format("%6d %s\n", count, line))
      count = count + 1
    end
    file:close()
end

--[[print("Who Am I?")
--file = io.popen("whoami", "r")
msg = "";
count = 1
while true do
  local line = file:read()
  if line == nil then break end
  msg = msg .. line
  print(string.format("%6d %s\n", count, line))
  count = count + 1
end
file:close()
--]]

for i,p in pairs(properties) do
    cgi[p]= os.getenv(p);
    if DEBUG then
        print("defining cgi." .. p .. "=" .. clean(os.getenv(p)));
    end
end

-- convert content_length to a number
if (cgi.CONTENT_LENGTH ~= nil) then
   cgi.CONTENT_LENGTH = tonumber(cgi.CONTENT_LENGTH)
end

-- Execute the child script passing in the environment object
local childscript=...

if DEBUG then
    print("childscript:", childscript);
end

if (childscript ~= nil) then
    if (string.match(childscript, "^/www/pages/secure/.*%.html$") ~= nil) then
        if DEBUG then
            print("sending CSRF file:" .. childscript)
        end
        send_page_withCSRFCookie(cgi, childscript)
    elseif (string.match(childscript, "^/www/pages/.*%.html$") ~= nil) then
        if DEBUG then
            print("sending ordinary file:" .. childscript)
        end
        send_page(cgi, childscript)
    elseif (string.match(childscript, "^/www/lua/.*%.lua$") ~= nil) then
        if DEBUG then
            print("running script:" .. childscript)
        end
        -- Launch requested lua script
        local f=assert(loadfile(childscript));
        if (f==nil) then
            LOG("childscript failed:" .. sanitize_input(childscript, true))
            send(f);
        else
            f(cgi);
        end
    else
        send(cgi.SERVER_PROTOCOL)
        send(" 403 Forbidden\r\n")
        send("\r\n\r\n")
    end
end
