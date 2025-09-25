#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: update-passwd.sh
#
# wrapper script for setting the password that respects debug mode. Called from 
# get-keys.lua and etm-prep.sh

# load our common functions, including UCI file support
. /etm/bin/etm-common.sh

SCRIPT_NAME="update-passwd.sh"

# this is a manufacturing error and should never occur on a production device
# would send a critical alert, but not very useful - would need at the least
# the MAC address.
if [ ! -f /etc/etm-serial ]; then
    log_err_msg "${SCRIPT_NAME}" "Event=MISSING_SERIAL_NUMBER"
fi

if [ ${ETM_DEBUG_BUILD} ]; then
    log_err_msg "${SCRIPT_NAME}" "Event=DebugSkipPasswordChange"
else
    # setup the password and token files
    if [ -x /etm/bin/etm-passwd ] && /etm/bin/etm-passwd; then
        # the following chmod/chown is required for get-blob.lua trigged by WebUI
        if [ -f /etc/config/challenge.txt ]; then
            /bin/chmod 640 /etc/config/challenge.txt
            /bin/chown root:wwwrun /etc/config/challenge.txt
        fi

        if [ -f /etc/config/challenge.txt.prev1 ]; then
            /bin/chmod 640 /etc/config/challenge.txt.prev1
            /bin/chown root:wwwrun /etc/config/challenge.txt.prev1
        fi

        # echo this because the LUA scripts need to see it for error status
        log_info_msg "${SCRIPT_NAME}" "Event=PasswordsRotated"
    else
        # the tool logged failure details.
        log_err_msg "${SCRIPT_NAME}" "Event=PasswordRotateFailed"
    fi
fi
