#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Convert WebUI username/password from the old clear text format, stored in
# /etc/lighttpd.user into more secured hashed password and store it in
# /etc/lighttpd.user.digest file 

. /etm/bin/etm-common.sh

LIGHTTPD_USER_CLEARTEXT="/etc/lighttpd.user"
SCRIPT_NAME="etm-update-cfg.sh"

if [[ -f "${LIGHTTPD_USER_CLEARTEXT}" ]]; then
    CREDENTIALS="$(/usr/bin/head -n 1 ${LIGHTTPD_USER_CLEARTEXT})"
    USERNAME="admin"
    PASSWORD="admin"
    if [[ -z "${CREDENTIALS}" ]]; then
        log_err_msg "${SCRIPT_NAME}" "Event=UpdateCfg_ReadCredsFailed Result=ResetToDefault"
    else
        # parse username
        PARSED_USERNAME="$(echo "${CREDENTIALS}" | /usr/bin/cut -d ':' -f 1)"
        PARSED_USERNAME_LEN=${#PARSED_USERNAME}
        if [[ -z "${PARSED_USERNAME}" ]] || [[ ${PARSED_USERNAME_LEN} -gt 512 ]]; then
            log_err_msg "${SCRIPT_NAME}" "Event=UpdateCfg_ParseFailed Result=ResetToDefault"
        else
            # save username
            USERNAME="${PARSED_USERNAME}"
            # parse password
            PASSWORD="${CREDENTIALS:$(( PARSED_USERNAME_LEN + 1 ))}"

            # this script allows empty passwords, in case if users set that intentionally
        fi
    fi

    /etm/bin/update-webuser.sh "${USERNAME}" "${PASSWORD}"
    /bin/rm -f "${LIGHTTPD_USER_CLEARTEXT}"
    log_info_msg "${SCRIPT_NAME}" "Event=WebUserConverted UserName=${USERNAME}"
fi
