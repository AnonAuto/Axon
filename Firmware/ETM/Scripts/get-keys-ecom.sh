#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: echo "ECOM_ADMIN_USER:ECOM_PASSWORD" | get-keys-ecom.sh
#   ECOM_ADMIN_USER - E.com user name with admin permissions
#   ECOM_PASSWORD   - password for ECOM_ADMIN_USER
#
# Gets authentication tokens from E.com and saves them to etm UCI configuration file.

. /etm/bin/etm-common.sh

SCRIPT_NAME="get-keys-ecom.sh"

# make sure that only one instance of this script is running
if [[ "$(/bin/ps -A 2>/dev/null | /bin/grep get-keys-ecom.sh | /usr/bin/wc -l)" -gt 2 ]]; then
    # comparing with 2 because the pipeline to compute get-keys-ecom.sh count
    # causes extra instances to appear in ps -A; no clue why, but best guess is
    # any commands run from a script show up in ps -A with the name
    # of the parent.
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=GetKeysAlreadyRunning"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/GetKeysAlreadyRunning" 
    exit 1
fi

ECOM_AGENCY_DOMAIN="$(/sbin/uci get "etm.operation.agency_domain")"
if [[ -z "${ECOM_AGENCY_DOMAIN}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AgencyDomainEmpty"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/AgencyDomainEmpty"
    exit 1
fi

DOCK_SERIAL="$(/bin/cat /etc/etm-serial)"
if [[ -z "${DOCK_SERIAL}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=SerialNumberEmpty"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/SerialNumberEmpty"
    exit 1
fi

# IFS= disables interpretation of spaces, without it leading and trailing spaces will be trimmed
# -s means secure mode, so no echo output to the console
# -r means raw input - disables interpretion of backslash escapes and line-continuation in the read data
# More info: http://wiki.bash-hackers.org/commands/builtin/read
IFS= read -s -r ECOM_AUTH
# submit ecom-admin generate-keys command, on success it completes with 0 and
# returns a string similar to:
# "Authentication: E20DEAB816F34D5889776C806D3432E6 CGJFLDwz4S0SQdL0gTHqrBxTj6gldAmz+TGvvmwpc0c"
ECOM_ADMIN_OUT="$(echo "${ECOM_AUTH}" | /etm/bin/ecom-admin g "${ECOM_AGENCY_DOMAIN}" "${DOCK_SERIAL}")"
if [[ $? -ne 0 ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAdminGenerateKeysFailed Output=\"${ECOM_ADMIN_OUT}\""
    # get-keys.lua needs error code and message, it reads it from standard output
    echo "${ECOM_ADMIN_OUT}"
    exit 1
fi

# split results in a positional parameters
# No double quotes around ECOM_ADMIN_OUT, otherwise it will be interpreted as a single parameter
set -- junk ${ECOM_ADMIN_OUT}
# get rid of junk
shift
# 'Authentication:' is $1
if [[ "$1" != "Authentication:" ]]; then
    # don't want to leak anything to the log, so just report the fact that ecom-admin
    # returned something weird
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAdminOutCorrupt"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAdminOutCorrupt" 
    exit 1
fi

ECOM_ACCESS_KEY="$2"
ECOM_SECRET_KEY="$3"

if [[ -z "${ECOM_ACCESS_KEY}" ]] || [[ -z "${ECOM_SECRET_KEY}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAuthEmpty"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAuthEmpty"
    exit 1
fi

# save the tokens to /etc/config/etm
# saving sensitive information, so calling uci directly
if (/sbin/uci set etm.operation.mode="agency" &&
   /sbin/uci set etm.operation.agency_domain="${ECOM_AGENCY_DOMAIN}" &&
   /sbin/uci set etm.operation.access_key="${ECOM_ACCESS_KEY}" &&
   /sbin/uci set etm.operation.secret_key="${ECOM_SECRET_KEY}" &&
   /sbin/uci set etm.operation.authenticated="1" &&
   /sbin/uci commit etm) ; then
    # Success!
    log_info_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAuthSaved"
    # get-keys.lua will read this message and interpret as a success
    echo "DONE:get-keys-ecom.sh"
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAuthSaveFailed"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAuthSaveFailed" 
    exit 1
fi
