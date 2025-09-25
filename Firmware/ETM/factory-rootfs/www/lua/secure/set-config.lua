package.path = package.path .. ";../?.lua" --set path for all libraries to the parent folder
--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file set-config.lua
 @brief update etm & network configuration.

--]]
require "lib.structs"
require "lib.base64"
require "os"
require "common"

local env = ...

LOG("set-config")

local req = safeReceiveJson(env)

-- validate will return an error reply if invalid, so we can just bail...
if not validate_csrf_token(env, req) then
    return
end

local commitList = Set:new{}
local commit = false
local ssl_change = false
local snmp_change = false

function getCfgValue(f, s, o)
    -- read the current value from /etc/config/etm
    local uci_key = f .. "." .. s .. "." .. o
    local cur_value = ""
    local cmd ="/usr/bin/sudo /www/scripts/get-uci-cfg.sh"
    LOG(cmd)
    local file = io.popen(cmd, "r")
    -- read the output line by line
    while true do
        local line = file:read()
        if line == nil then
            break
        elseif line:find("^" .. uci_key .. "=.*$") then
            -- read the value
            cur_value = split(line, "=")[2]
            cur_value = remove_uci_show_escape(cur_value)
            break
        end
    end
    file:close()

    return cur_value
end

function setCfgValue(cfg, f, s, o)
    local value = cfg[s]
    local rc = 1

    if (value ~= nil) then
        value = value[o]
    end

    if (value ~= nil) then
        local uci_key = f .. "." .. s .. "." .. o
        -- escape ' (single quote) with '\'' sequence to satisfy strong quoting requirements
        -- http://wiki.bash-hackers.org/syntax/quoting#strong_quoting
        value = value:gsub("'", "'\\''")      -- replace ['] with ['\'']
        rc = syscall_exec("/usr/bin/sudo /www/scripts/uci-option.sh set '" .. uci_key .. "' '" .. value .. "'")
    end

    return (rc == 0)
end

function delCfgValue(cfg_item)
    local rc = 1
    if (cfg_item ~= nil) then
        rc = syscall_exec("/usr/bin/sudo /www/scripts/uci-option.sh delete '" .. cfg_item .. "'")
    end
    return (rc == 0)
end

-- set and detect new value is different than old value
function setCfgValueChange(cfg, f, s, o)
    local set_cfg_value_required = false

    -- get the new value
    local new_value = cfg[s]
    if (new_value ~= nil) then
        new_value = new_value[o]
    end

    return ((new_value ~= nil) and (not compareCfgValue(f, s, o, new_value)) and (setCfgValue(cfg, f, s, o)))
end

function compareCfgValue(f, s, o, expected)
    local cur_value = getCfgValue(f, s, o)
    return (tostring(expected) == cur_value)
end

function setForceSSL(accept_only_https)
    local value = tonumber(accept_only_https)
    local conf_file = "nossl"
    if(value == 1) then conf_file =  "sslonly" end
    local rc = syscall_exec("/usr/bin/sudo /www/scripts/set-force-ssl.sh '" .. conf_file .. "'")
    if (rc == 0) then
        return true
    else
        return false
    end
end

function updateNetwork(cfg)
    LOG("updating network configuration:")
    local cmd = "/usr/bin/sudo /etm/bin/stage-wan-setting-changes.sh " .. sanitize_input(cfg.wan.proto, true)
    if (cfg.wan.proto == 'static') then
        cmd = cmd .. " " .. sanitize_input(cfg.wan.ipaddr, true) .. " " .. sanitize_input(cfg.wan.netmask, true) .. " " .. sanitize_input(cfg.wan.gateway, true)
        if (cfg.wan.dns ~= nil) then
            for i = 1, #cfg.wan.dns do
                cfg.wan.dns[i] = sanitize_input(cfg.wan.dns[i], true)
            end
            local dns = table.concat(cfg.wan.dns, " ")
            cmd = cmd .. " " .. dns
        end
    end

    response, std_out = syscall(cmd)
    return response
end

-- update SNMP settings. Returns output object with parameters:
-- err, msg, msgkey
function updateSNMP(cfg)
    output = {err=0, msg="", msgkey=""}

    local cmd = "/usr/bin/sudo /www/scripts/generate-snmpv3-user.sh >/dev/null 2>&1"
    local enable_snmp = tonumber(cfg.etm.etm.enable_snmp)

    if (enable_snmp ~= 1) then -- set to disable
        snmp_change = setCfgValueChange(cfg.etm, "etm", "etm", "enable_snmp") or snmp_change
        if(snmp_change) then
            local snmp_conf = "echo 0 | "
            local rc = syscall_exec(snmp_conf .. cmd)
            if (rc ~= 0) then
                -- Revert back to original flag if script failed to execute.
                cfg.etm.etm.enable_snmp="1"
                setCfgValue(cfg.etm, "etm", "etm", "enable_snmp") -- this should not fail if setCfgValueChange succedded
                output.err = 1
                output.msg = "Unable to apply SNMP configuration."
                output.msgkey="ETM.cgi.unable_set_snmp"
            else -- able to successfully disable snmp so remove other data from config file
                if not delCfgValue("etm.etm.snmp_user") then
                    output.err = 1.1
                    output.msg = "Unable to disable SNMP configuration."
                    output.msgkey="ETM.cgi.unable_disable_snmp"
                end
            end
        end
    else -- snmp is enabled
        -- check to see if the settings of snmp is any different from what is stored, only then save/update it
        -- compare if any of these changed: username, authentication, encryption, or encryption password is not blank.
        -- if above is true, then a password for snmp is required. otherwise all input is the same so nothing to save.
        local values_changed = not compareCfgValue("etm", "etm", "enable_snmp", enable_snmp)
        values_changed = values_changed or not compareCfgValue("etm", "etm", "snmp_auth", cfg.etm.etm.snmp_auth)
        values_changed = values_changed or not compareCfgValue("etm", "etm", "snmp_encrypt", cfg.etm.etm.snmp_encrypt)
        values_changed = values_changed or cfg.snmp_encryption_password ~= nil

        if (values_changed and cfg.snmp_password == nil) then --something to update but snmp password was not provided
            LOG("Event=UnableEnableSnmp Reason=NoSnmpPassword")
            output.err = 3
            output.msg = "Unable to apply SNMP configuration. No Password provided."
            output.msgkey="ETM.cgi.no_snmp_pw"

        elseif (cfg.etm.etm.snmp_user ~= nil and
            cfg.snmp_password ~= nil and
            cfg.etm.etm.snmp_auth ~= nil and
            cfg.etm.etm.snmp_encrypt ~= nil) then

            -- sanitizer allows spaces. but snmp user field does not work well with spaces. so dont allow that either.
            -- if the sanization here changes, update the webui validator function to also notify user of invalid
            -- data appropriately
            local snmp_user = string.gsub(sanitize_input(cfg.etm.etm.snmp_user, false), "[%s]", "")
            local snmp_password = to_base64(esc_ansi_cstr(cfg.snmp_password))
            cfg.etm.etm.snmp_auth = sanitize_input(cfg.etm.etm.snmp_auth, false)
            cfg.etm.etm.snmp_encrypt = sanitize_input(cfg.etm.etm.snmp_encrypt, false)

            -- if some characters had to be sanitized then we have invalid data. do not allow invalid data!
            if snmp_user ~= cfg.etm.etm.snmp_user then
                output.err = 4
                output.msg = "Unable to apply SNMP configuration. Invalid SNMP user name."
                output.msgkey="ETM.cgi.invalid_snmp_user"

            else
                local snmp_encrypt = cfg.etm.etm.snmp_encrypt
                local snmp_security = "priv"

                if snmp_encrypt == "NoPriv" then
                    snmp_security = "auth"
                    snmp_encrypt = "AES" --don't care value. need to be set to some default value for script parameter
                end

                local dltr = ";"
                local snmp_conf = cfg.etm.etm.snmp_user .. dltr .. snmp_password .. dltr
                                            .. snmp_security .. dltr .. cfg.etm.etm.snmp_auth .. dltr .. snmp_encrypt .. dltr
                local snmp_encrypt_pass = ""
                if (cfg.snmp_encryption_password ~= nil and snmp_security == "priv") then
                    snmp_encrypt_pass = to_base64(esc_ansi_cstr(cfg.snmp_encryption_password))
                end
                snmp_conf = "echo \"" ..  snmp_conf .. snmp_encrypt_pass .. dltr .. "\" | "

                local rc = syscall_exec(snmp_conf .. cmd)
                if (rc == 0) then
                    -- Only apply changes if script is success and move to next step
                    snmp_change = true
                    if not setCfgValue(cfg.etm, "etm", "etm", "enable_snmp") then
                        output.err = 4.1
                        output.msg = "Unable to enable SNMP configuration."
                        output.msgkey = "ETM.cgi.unable_set_snmp_enable"
                        snmp_change = false
                    end
                    if snmp_change and not setCfgValue(cfg.etm, "etm", "etm", "snmp_user") then
                        output.err = 4.2
                        output.msg = "Unable to apply SNMP configuration username."
                        output.msgkey = "ETM.cgi.unable_set_snmp_user"
                        snmp_change = false
                    end
                    if snmp_change and not setCfgValue(cfg.etm, "etm", "etm", "snmp_auth") then
                        output.err = 4.3
                        output.msg = "Unable to apply SNMP configuration Authentication."
                        output.msgkey = "ETM.cgi.unable_set_snmp_auth"
                        snmp_change = false
                    end
                    if snmp_change and not setCfgValue(cfg.etm, "etm", "etm", "snmp_encrypt") then
                        output.err = 4.4
                        output.msg = "Unable to apply SNMP configuration encryption."
                        output.msgkey = "ETM.cgi.unable_set_snmp_enc"
                        snmp_change = false
                    end
                else -- error
                    output.err = 4.5
                    output.msg = "Unable to apply SNMP configuration password."
                    output.msgkey = "ETM.cgi.unable_set_snmp_pass"
                end
            end
        end
    end

    return output
end

-- update proxy settings. Returns output object with parameters:
-- err, msg, msgkey
function updateProxy(proxy)
    local cmd = "/usr/bin/sudo /www/scripts/set-http-proxy.sh"

    local enabled = tonumber(proxy.enabled)
    if (enabled == 0) then -- set to disable
        local cmdComplete = "echo 0 | " .. cmd
        local response, std_out = syscall_nocmdlog(cmdComplete)
        return response
    else -- proxy is enabled
        local disable_dns_check = tonumber(proxy.disable_dns_check)
        if (proxy.username and proxy.password) then
            local cmdComplete = "echo $'" .. esc_ansi_cstr(proxy.username) .. ":" .. esc_ansi_cstr(proxy.password) .. "' | " .. cmd .. " " .. sanitize_input(proxy.host, true) .. " " .. sanitize_input(proxy.port, true) .. " --disable-dns-check=" .. tostring(disable_dns_check)
            local response, std_out = syscall_nocmdlog(cmdComplete)
            return response
        elseif (proxy.username == nil and proxy.password == nil) then
            local cmdComplete = "echo - | " .. cmd .. " " .. sanitize_input(proxy.host, true) .. " " .. sanitize_input(proxy.port, true) .. " --disable-dns-check=" .. tostring(disable_dns_check)
            local response, std_out = syscall_nocmdlog(cmdComplete)
            return response
        else
            return {err=1, msg="Username or password is missing", msgkey="ETM.cgi.invalid_proxy_user_pass"}
        end
    end

    return {err=1, msg="Invalid proxy configuration", msgkey="ETM.cgi.invalid_proxy_config"}
end

function updateETM(cfg)
    -- trigger snmp_change when location is changed.
    snmp_change = not compareCfgValue("etm", "etm", "location", cfg.etm.location) or snmp_change

    -- remove HTML tags from input to prevent Cross Site Scripting
    if (cfg.etm) then
        local ecom_status = 0

        if (cfg.etm.name) then
            cfg.etm.name = string.gsub(cfg.etm.name, "[<>]", "")
            cfg.etm.name = sanitize_input(cfg.etm.name, false)
            if (cfg.etm.name != '') then
                commit = setCfgValue(cfg, "etm", "etm", "name") or commit
                ecom_status = ecom_status + os.execute("/usr/bin/sudo /www/scripts/ecom.sh set-device-name '" .. cfg.etm.name .. "' > /dev/null")
            end
        end
        if (cfg.etm.location) then
            cfg.etm.location = string.gsub(cfg.etm.location, "[<>]", "")
            commit = setCfgValue(cfg, "etm", "etm", "location") or commit
        end
        if (cfg.etm.agency) then
            cfg.etm.agency = string.gsub(cfg.etm.agency, "[<>]", "")
            commit = setCfgValue(cfg, "etm", "etm", "agency") or commit
        end
        if (cfg.etm.device_home) then
            cfg.etm.device_home = string.gsub(cfg.etm.device_home, "[<>]", "")

            -- The device home submitted value is: <home-id>,<home-name>
            -- must be care full here, home-id is for ecom, the name is saved to /etc/config/etm
            local vals = split(cfg.etm.device_home, ',')
            cfg.etm.device_home = sanitize_input(vals[2], false)
            commit = setCfgValue(cfg, "etm", "etm", "device_home") or commit
            -- Remove home if home_id is empty
            local home_id = ''
            if (vals[1] != '' and vals[1] != 'none') then home_id = vals[1] end
            ecom_status = ecom_status + os.execute("/usr/bin/sudo /www/scripts/ecom.sh set-device-home " .. sanitize_input(home_id, false) .. " > /dev/null")
        end

        if (ecom_status == 0) then
            cfg.etm.ecom_sync = "1"
            commit = setCfgValue(cfg, "etm", "etm", "ecom_sync") or commit
        end
    end

    commit = setCfgValue(cfg, "etm", "etm", "require_https_time") or commit
    commit = setCfgValue(cfg, "etm", "etm", "netlimit_kbitps") or commit

    -- flag to keep track the change in "accept_only_https"
    ssl_change = setCfgValueChange(cfg, "etm", "etm", "accept_only_https")
end

-- main
send_header(env)


local r = ERR_NO_CONTENT
if (env.CONTENT_LENGTH ~= 0) then
    if (req.etm and req.etm.etm) then
        -- Slight hack.
        -- This function converts data from UI to the storage format.
        convertForSave(req.etm)
        updateETM(req.etm)
    end

    r = ERR_NO_ERROR
    if (req.network) then
        r = updateNetwork(req.network)

        if (r.err == 0) then
            LOG("set-config network updated:" .. tostring(r.msg))
            r = ERR_NO_ERROR
            commitList:add("network")
        end
    end

    if (ssl_change) then
        if(not setForceSSL(req.etm.etm.accept_only_https)) then
            r.err = 1
            r.msg = "Unable to change 'Accept Only SSL Requests' setting"
            r.msgkey="ETM.cgi.unable_set_sslonly"
        end
    end

    if ((r.err == 0) and (req.etm and req.etm.etm)) then
        out = updateSNMP(req)
        if (out.err ~= 0) then -- check if update was successful or not
            r.err = out.err
            r.msg = out.msg
            r.msgkey = out.msgkey
        end
    end

    if ((r.err == 0) and (req.etm and req.etm.proxy)) then
        out = updateProxy(req.etm.proxy)
        if (out.err ~= 0) then -- check if update was successful or not
            r.err = out.err
            r.msg = out.msg
            r.msgkey = out.msgkey
        else
            commitList:add("proxy")
        end
    end
end

send (json.encode(r))

-- Trigger uci commit on etm if any of etm.etm.* changed.
if (commit or ssl_change or snmp_change) then
    -- network no longer uses UCI, so we can commit all changes now
    LOG("COMMIT: etm")
    syscall_exec("/usr/bin/sudo /www/scripts/uci-commit-etm.sh")
end

if (snmp_change) then
    LOG("set-config scheduling snmpd restart")
    set_webui_req("snmpd")
end

-- Trigger lighttpd restart. This needs to be done after the response is sent
-- above, hence doing it via webUI.req/etm-watchdog.sh
if (ssl_change) then
    LOG("set-config scheduling lighttpd restart")
    LOG("Event=ScheduleLighttpdRestart Reason=accept_only_https Value='" .. req.etm.etm.accept_only_https .. "'")
    set_webui_req("lighttpd")
end

-- Trigger network restart. This needs to be done after the response is sent
-- above, hence doing it via webUI.req/etm-watchdog.sh
if commitList:contains("network") then
    LOG("set-config scheduling network restart and status update")
    set_webui_req("network")
end

-- Trigger etmd restart to use new proxy configuration
if commitList:contains("proxy") then
    LOG("set-config scheduling etm restart")
    set_webui_req("etm")
end
