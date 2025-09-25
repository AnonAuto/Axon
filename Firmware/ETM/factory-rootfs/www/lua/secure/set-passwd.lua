package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file set-passwd.lua
 @brief update password to "secure" section of WebUI.

--]]
require "lib.structs"
require "lib.base64"
require "common"
require "string"
require "os"

local env = ...

LOG("set-passwd")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

send_header(env)

if (env.CONTENT_LENGTH == 0) then
    send(ERR_NO_CONTENT)
    return
end

-- saved as 'web_admin_user' and hash will be calculated based on quotes
local web_admin_user = sanitize_input(req.web_admin_user, false)
local web_admin_cur_pass = to_base64(esc_ansi_cstr(req.web_admin_cur_pass))
local web_admin_new_pass = to_base64(esc_ansi_cstr(req.web_admin_new_pass))

-- play it safe - double check data after sanitation/base64 encoding
if (web_admin_user == nil or web_admin_user == '' or web_admin_user ~= req.web_admin_user) then
    send(json.encode({err = 1, msg = "Failed to update Administrator credentials: username is invalid.", msgkey = "ETM.cgi.web_creds_invalid_username" }))
    return
elseif (web_admin_cur_pass == nil or web_admin_cur_pass == '') then
    send(json.encode({err = 1, msg = "Failed to update Administrator credentials: current password is invalid.", msgkey = "ETM.cgi.web_creds_invalid_cur_pass" }))
    return
elseif (web_admin_new_pass == nil or web_admin_new_pass == '') then
    send(json.encode({err = 1, msg = "Failed to update Administrator credentials: new password is invalid.", msgkey = "ETM.cgi.web_creds_invalid_new_pass" }))
    return
end

local dltr = ";"
-- not using syscall_exec since don't want to expose web_admin_pass in the syslog
local auth = "echo \"" .. web_admin_user .. dltr .. web_admin_cur_pass .. dltr .. web_admin_new_pass .. "\" | "
local cmd = "/usr/bin/sudo /www/scripts/set-lighttpd-passwd.sh"
LOG(cmd)
-- using io.popen to capture the output from set-lighttpd-passwd.sh
-- the script echoes "DONE:set-lighttpd-passwd.sh" and returns 0 on success
-- or echoes "ERR:RC_INT/ID_STR" and returns RC_INT on error, where
--     RC_INT - an integer > 0, usually it is 1
--     ID_STR - unique string identifier describing an error, i.e. "WebAdminAuthEmpty"
local file = io.popen(auth .. cmd, "r")
local output = file:read("*a")
file:close()
local l = lines(output)
local l_arr = l[#l]
LOG(l_arr)

if (l_arr:find("DONE:set%-lighttpd%-passwd%.sh") == 1) then
    -- There's no need to restart lighttpd. Dock will ask for new user immediately.
    send(json.encode(ERR_NO_ERROR))
elseif (l_arr:find("ERR:") == 1) then
    -- error message has the following format: ERR:RC_INT/ID_STR (see comments above)
    -- parsing out RC_INT and ID_STR
    local rc_int
    local id_str
    rc_int, id_str = l_arr:match("(%d+)/([^/]*)")
    if (id_str == "WebAdminCurPasswdInvalid") then
        send(json.encode({err = 1, msg = "Failed to update Administrator credentials: current password is invalid.", msgkey = "ETM.cgi.web_creds_invalid_cur_pass" }))
    else
        send(json.encode({err = 1, msg = "Failed to update Administrator credentials.", msgkey = "ETM.cgi.web_creds_err" }))
    end
else
    send(json.encode({err = 2, msg = "Unknown error.", msgkey = "ETM.cgi.unknown_err" }))
end
