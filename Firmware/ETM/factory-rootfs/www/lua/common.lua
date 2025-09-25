--[[

 Copyright (c) 2013 TASER International, Inc.
 All Rights Reserved
 TASER Data Classification: CONFIDENTIAL

 @file common.lua
 @brief misc helper utilities. Do not write any code here that could be executed just by calling this script as an API.
 Since it is not in the secure folder, it can be called as an APIRequest from web ui / developer console.

--]]

function lines(str)
    local t = {}
    local function helper(line) if (line ~= "") then table.insert(t, line) end return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

-- function that returns an empty string if no data posted
function safeReceiveJson(env)
    data = recv(env)
    if data ~= nil then
        data = json.decode(data)
    else
        data = ""
    end
    return data
end

function gen_csrf_cookie()
    local r, l = syscall_nocmdlog("/usr/bin/sudo /www/scripts/random.sh")
    if (r.err == 0) then
        return r.msg
    end
    return "cookieerror1"
end

function send_page(env, webpage, withcookie)
    -- some files not set with CSRF cookie because they are not web pages with forms
    -- and we don't want to reset the browser cookie in case there is an actual
    -- form open with the cookie

    send(env.SERVER_PROTOCOL)
    send(" 200 OK\r\n")
    csrf_cookie = ""
    if withcookie ~= nil then
        csrf_cookie = gen_csrf_cookie(env)
        -- enforce path to avoid problems with multiple cookies since we don't want
        -- to allow the submission to match against one of multiple
        send("Set-Cookie: XSRFDSC=" .. csrf_cookie .. ";Path=/;HttpOnly\r\n");
    end
    send("Content-Type:text/html;charset=UTF-8\r\n");
    send("\r\n")

    local BUFSIZE = 2^13     -- 8K
    local f = io.input(webpage)   -- open input file
    while true do
        local txt, rest = f:read(BUFSIZE, "*line")
        if not txt then
            break
        end
        -- if txt is broken by BUFSIZE, finish reading it
        if rest then
            txt = txt .. rest .. '\n'
        end
        -- substitute CSRF token
        local txt,t = string.gsub(txt, "__CSRF_TOKEN_PLACEHOLDER__", csrf_cookie)
        if t > 0 then
            LOG("Event=Set_CSRF_TOKEN Cookie=".. csrf_cookie .. " Count=" .. tostring(t))
        end
        send(txt)
    end
end

function send_page_withCSRFCookie(env, webpage)
    send_page(env, webpage, true)
end

function validate_csrf_token(env, req)
    local success = 0

    if req ~= nil and req.token ~= nil and env.HTTP_COOKIE ~= nil then
        -- parse cookies, looking for a match
        -- in this case, since all pages should share the same path, we
        -- enforce that assumption here and fail if the cookie list consists of anything
        -- other than a single cookie.
        local prefix, cookie, others
        _,_, prefix, key, value, remainder = string.find(env.HTTP_COOKIE, "(.*)(XSRFDSC)=(.*);?(.*)")

        if key == "XSRFDSC" and prefix == "" and remainder == "" and value == req.token then
            success = 1
        end
    end
    if success ~= 1 then
        if req ~= nil then
            LOG("Event=CsrfVerificationFailure Token=".. tostring(req.token) .. " Cookie=" .. tostring(env.HTTP_COOKIE))
        else
            LOG("Event=CsrfVerificationFailure Reason=ReqNotDefined")
        end

        send_header(env)
        send( json.encode(csrf_deny_response()) )
        return false
    end
    return true
end

function send_header(env)
    send(env.SERVER_PROTOCOL)
    send(" 200 OK\r\n")
    send("Content-type: text/plain\r\n\r\n")
end

function ok_response()
    return  ERR_NO_ERROR
end
function csrf_deny_response()
    return  ERR_CSRF_ERROR
end

function endsWith(s, send)
    return #s >= #send and s:find(send, #s-#send+1, true) and true or false
end

function syscall_nocmdlog(cmd)
    local response = ok_response()
    local l = nil
    local file = io.popen(cmd, "r")
    local output = file:read("*a")
    file:close()
    local l = lines(output)
    response.msg = l[#l]
    if (response.msg ~= nil) then
        if (response.msg:find("ERR:") == 1) then
          response.err, response.msg = response.msg:match("(%d+)/([^/]*)")
          LOG(tostring(response.err))
          LOG(response.msg)
        --the ERROR: string could be at any location inside the message.
        --so check for presence in the string only, instead of index value
        elseif (response.msg:find("ERROR:") ~= nil) then
          response.msg = response.msg:match("ERROR:([^/]*)")
          response.err = 1
          LOG("error syscall.msg")
          LOG(response.msg)
        end
    end
  -- return response summary, and standard output
  return response, l
end

function syscall(cmd)
    LOG("executing [" .. cmd .. "]")
    return syscall_nocmdlog(cmd)
end

function syscall_exec(cmd)
    -- logs then executes shell command using os.execute and returns its completion status
    LOG("executing [" .. cmd .. "]")
    return os.execute(cmd)
end

function split(p,d)
    local t, ll
    t={}
    ll=0
    if(#p == 1) then return {p} end
        while true do
            l=string.find(p,d,ll,true)
            if l~=nil then
                table.insert(t, string.sub(p,ll,l-1))
                ll=l+1
            else
                table.insert(t, string.sub(p,ll))
                break
            end
        end
    return t
end

-- CAUTION: PLEASE READ!!!
-- many webUI fields are santized by this function. Any changes done here impacts what the user can provide on webUI.
-- So, update common.js field validator function when this is updated to stay consistent.
function sanitize_input(str, quote_output)
-- test expression:  print(string.gsub("abcxyz ABCGHXYZ 012789 `~!@#$%^&*()_+-=[]\{}|;':\",./<>?", "[^%w%s%#%!%@%(%)%[%]%-%.%_]"," "))
-- expected output for the test: abcxyz ABCGHXYZ 012789 !@#()_-[].

    -- this function is used for removal of unwanted characters from parameters
    -- which passed from WebUI to underlying shell scripts/commands;
    -- don't escape them because the use down the road is unknown
    -- and might be unescaped.
    -- keep only these characters:
    -- %w - alpha/numeric
    -- %s - whitespace
    -- #, !, @, (, ), [, ], -, ., _

    -- ensure that input parameter is a string, otherwise convert it to a string
    str=tostring(str)
    str=str:gsub("[^%w%s%#%!%@%(%)%[%]%-%.%_]", "")
    -- return output in single quotes so shell doesn't try to split or interpret it
    if quote_output == true then
        return '\'' .. str .. '\''
    else
        return str
    end
end

function esc_ansi_cstr(str)
    -- this function replaces backslash[\] and single quote['] characters in the given string
    -- with escape sequences so this string can be safely consumed by get-keys-ecom.sh,
    -- register-ecom.sh and set-lighttpd-passwd.sh shell scripts;
    -- we use "echo $'str' | shell_script.sh" to pass the data to the script, $'str' is ANSI C-like
    -- strings supported by shell, more information:
    --   http://wiki.bash-hackers.org/syntax/quoting
    --   http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_03.html
    str = tostring(str)
    str = str:gsub("\\", "\\\\")    -- replace [\] with [\\]
    str = str:gsub("'", "\\'")      -- replace ['] with [\']
    str = str:gsub("\"", "\\\"")    -- replace ["] with [\"]
    return str
end

--Get the status of dock. This information is for the main/index page.
--Parameters:
--  secure: true/false indication whether to retrieve back secured information or not.
--  env: (vararg "...") arguments from the caller
function get_status(secure, env)
    local cfilename = "/tmp/corruption"
    local options = "-n"

    LOG("get-status")

    send_header(env)

    --additional option needed when needing to hide data
    if(not secure) then
        options = options .. " -s"
    end

    local cmd = "/etm/bin/etm-status ".. options .. " /tmp/status.config"
    LOG(cmd)
    local file = io.popen(cmd, "r")
    local response = {err = 0}
    -- this is stupid code - it assumes there is only one line in the file,
    -- or it keeps only the last line! So don't pretty print the XML in the
    -- status process or this will break!
    for line in file:lines() do
        response.xml = line
    end

    response.bad = {}
    for line in io.lines(cfilename) do
        parts = split(line, '/');
        dev = parts[4];
        if (response.bad[dev] == nil) then
            response.bad[dev] = {}
        end

        local fn = parts[#parts];
        local s = string.find(fn, ".bad.");
        fn = string.sub(fn, 1, s-1);
        table.insert(response.bad[dev], {file = fn, path = line});
    end

    send(json.encode(response))
end


function gen_password()
    local response = {err = 1, msg="PasswordChangeFailed", msgkey="ETM.cgi.passwd_chg_failed"}
    local cmd = "/usr/bin/sudo /etm/bin/update-passwd.sh"
    LOG(cmd)
    local file = io.popen(cmd, "r")
    local msg = "";
    while true do
        local line = file:read()
        if line == nil then
            break
        end
        if (line:find("Event=PasswordsRotated") != nil) then
            response.err = 0
            response.msg = "PasswordChangeComplete"
            response.msgkey = "ETM.cgi.passwd_chg_complete"
        elseif (line:find("Event=DebugSkipPasswordChange") != nil) then
            response.err = 0
            response.msg = "DebugSkipPasswordChange"
            response.msgkey = "ETM.cgi.passwd_chg_skipped"
        end
        LOG(string.format("%s\n", line))
    end

    file:close()
    LOG(response.msg)
    return response
end

-- Saves request passed from WebUI to /tmp/webUI.req.<SECONDS>.<MILLISECONDS> file
-- which is consumed by /etm/bin/etm-watchdog.sh.
-- Accepts req parameter - a text string which contains a special request,
-- e.g. "etm" to restart etmd or "system" to reboot the Dock.
-- Check handle_web_requests() function from /etm/bin/etm-watchdog.sh for full
-- list of requests.
function set_webui_req(req)
    -- read timestamp in seconds since the Epoch;
    -- it is expected to be in the following format: SECONDS.MILLISECONDS
    local cmd = "/usr/bin/sudo /www/scripts/gettimeofday.sh"
    LOG(cmd)
    local file = io.popen(cmd, "r")
    local timestamp = file:read("*a")
    file:close()
    -- remove any spaces, new lines, etc
    timestamp = timestamp:gsub("%s", "")
    -- validate
    if (nil == string.match(timestamp, "^[0-9]*%.[0-9]*$")) then
        -- failed to read timestamp from /www/scripts/gettimeofday.sh script;
        -- the chance of this failure is very low, but we need to try to recover
        -- and submit webUI request, though using Lua's built-in os.time()
        -- to get seconds since the Epoch (but without milliseconds),
        -- this approach gives us a good chance of getting unique filename;
        -- resulting timestamp will be something like "1452305758.000000"
        LOG("Failed to get timestamp from /www/scripts/gettimeofday.sh, using os.time() instead")
        timestamp = os.time() .. ".000000"
    end

    local req_file, err, errno = io.open("/tmp/webUI.req." .. timestamp, "w")
    if (req_file != nil) then
        req_file:write(req)
        req_file:close()
    else
        LOG("Event=SetWebUIReqFailed Err='" .. err .. "' Errno=" .. errno)
    end
end

-- Slight hack.
-- This function converts data from the UI format to the internal storage format.
--
-- Some values (notably netlimit_kbitps) are stored in one format and presented in the UI in a different value.
-- (for netlimit_kbitps, the storage format is in Kbps, not Mbps because /bin/ash can't handle floating point values
--  correctly.  But the UI presents Mbps.)
--
-- Because of the way the UI was built around using configuration keys in the UI layer it's inconvenient to handle
-- special values there.
--
-- This happens here, not in the bash scripts specifically because the conversions are too tedious in bash - which
-- is why the conversion doesn't happen at the final usage location.
function convertForSave(etmCfg)
    if (etmCfg ~= nil and etmCfg.etm ~= nil ) then
        local mbps=tonumber( etmCfg.etm.netlimit_mbitps )

        -- empty until proven otherwise
        etmCfg.etm.netlimit_kbitps = "";
        etmCfg.etm.netlimit_mbitps = nil;

        if (mbps ~= nil) then
            local kbps = math.floor(mbps * 1000);
            if (kbps >= 0 and kbps <= 320000) then
                etmCfg.etm.netlimit_kbitps = tostring(kbps)
                LOG("Event=SetNetSpeedLimit kbitps='" .. etmCfg.etm.netlimit_kbitps .. "'" )
            else
                LOG("Event=NetLimitOutOfRange kbitps='" .. kbps .. "'" )
            end
        end
    end
end

-- Slight hack.
-- This function converts data from the storage format to the UI format.
--
-- See above for longer explanation
function convertForUI(etmCfg)
    if (etmCfg ~= nil and etmCfg.etm ~= nil) then
        local kbps=tonumber( etmCfg.etm.netlimit_kbitps )
        if (kbps ~= nil and (kbps < 500 or kbps > 320000)) then
            kbitps = nil
        end

        -- empty until proven otherwise
        etmCfg.etm.netlimit_mbitps = "";
        etmCfg.etm.netlimit_kbitps = nil;

        if (kbps ~= nil) then
            local mbps = tonumber(string.format("%.1f", kbps / 1000))
            -- LOG("etmCfg.etm.netlimit_mbitps ='" .. mbps .. "'" )
            etmCfg.etm.netlimit_mbitps = mbps;
        end
    end
end

-- convert string to original form (e.g., `'X79045459\'\''Test'` -> `X79045459\'Test`)
-- `uci show` adds prepend and append string with ', and replace every ' with '\'
-- reference https://git.openwrt.org/?p=project/uci.git;a=blob;f=cli.c;hb=52bbc99f69ea6f67b6fe264f424dac91bde5016c#l200
function remove_uci_show_escape(val)
    if (val:len() >= 2) and (val:sub(1, 1) == '\'') and (val:sub(-1, -1) == '\'') then
        -- remove first and last quote (e.g., `'X79045459\'\''Test'` -> `X79045459\'\''Test`)
        val = val:sub(2, -2)
        -- replace '\'' with ' (e.g., `X79045459\'\''Test` -> `X79045459\'Test`)
        val = val:gsub("'\\''", "'")
    end

    return val
end

-- Takes configuration string like:
--    etm.etm.buildinfo='DOCK-1223@b8e22a80229d01b4a4aabfd75a1d4afe7d0d8382 (artem@evidence.com)'
-- parses it and saves key and value to a target table
function append_to_table(tbl, str, section)
    -- remove 'etm.<section>.' prefix from the initial sting to
    -- get '<key>=<val>' string
    local key_val_str = str:gsub("^etm%." .. section .."%.", "")
    -- split '<key>=<val>' into '<key>' and '<val>'
    local parts = split(key_val_str, "=")
    local key = parts[1]
    local val = key_val_str:gsub("^".. key .. "=", "")
    val = remove_uci_show_escape(val)

    -- save results to the table
    tbl[key]=val
end

-- read configuration and transform it into response.
-- cmd: the command to run to get the configuration or header output.
function transform_configuration(cmd, response)
    LOG(cmd)

    local file = io.popen(cmd, "r")
    -- read the output line by line
    while true do
        local line = file:read()
        if line == nil then
            break
        elseif line:find("^etm%.etm%.[%a%u%d_]+=.+$") then
            -- etm
            append_to_table(response.etm.etm, line, "etm")
        elseif line:find("^etm%.operation%.[%a%u%d_]+=.+$") then
            -- operation
            append_to_table(response.etm.operation, line, "operation")
        elseif line:find("^etm%.firmware%.[%a%u%d_]+=.+$") then
            -- firmware
            append_to_table(response.etm.firmware, line, "firmware")
        elseif line:find("^etm%.early_access_firmware%.[%a%u%d_]+=.+$") then
            -- early access firmware
            append_to_table(response.etm.early_access_firmware, line, "early_access_firmware")
        elseif line:find("^etm%.proxy%.[%a%u%d_]+=.+$") then
            -- proxy
            append_to_table(response.etm.proxy, line, "proxy")
        end
    end

    file:close()
    return response
end
