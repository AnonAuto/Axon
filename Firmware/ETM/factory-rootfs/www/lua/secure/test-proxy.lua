package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

  Copyright (c) 2022 TASER International, Inc.
  All Rights Reserved
  TASER Data Classification: CONFIDENTIAL

  @file test-proxy.lua
  @brief Test proxy configuration

--]]

require "common"

local env = ...

LOG("Event=test-proxy")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

function testProxy(proxy)
    local cmd = "/usr/bin/sudo /www/scripts/set-http-proxy.sh"

    if (proxy.username and proxy.password) then
        local cmdComplete = "echo $'" .. esc_ansi_cstr(proxy.username) .. ":" .. esc_ansi_cstr(proxy.password) .. "' | " .. cmd .. " " .. sanitize_input(proxy.host, true) .. " " .. sanitize_input(proxy.port, true) .. " test"
        local response, std_out = syscall_nocmdlog(cmdComplete)
        return response
    elseif (proxy.username == nil and proxy.password == nil) then
        local cmdComplete = "echo - | " .. cmd .. " " .. sanitize_input(proxy.host, true) .. " " .. sanitize_input(proxy.port, true) .. " test"
        local response, std_out = syscall_nocmdlog(cmdComplete)
        return response
    else
        return {err=1, msg="Username or password is missing", msgkey="ETM.cgi.invalid_proxy_user_pass"}
    end

    return {err=1, msg="Invalid proxy configuration", msgkey="ETM.cgi.invalid_proxy_config"}
end

send_header(env)

local r = ERR_NO_CONTENT
if (env.CONTENT_LENGTH ~= 0) then
    if (req.etm and req.etm.proxy) then
        r = testProxy(req.etm.proxy)
    end
end

send (json.encode(r))
