#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2023 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: register-ecom-universal-login.sh
#
# Do 2 things: 
# - Registers this dock on E.com and saves registration information to etm UCI configuration file (cloned from register-ecom.sh)
# - Get access key and save to em UCI configuration file (cloned from get-keys.sh)


. /etm/bin/etm-common.sh

SCRIPT_NAME="register-ecom-universal-login.sh"

# make sure that only one instance of this script is running
if [[ "$(/bin/ps -A 2>/dev/null | /bin/grep register-ecom-universal-login.sh | /usr/bin/wc -l)" -gt 2 ]]; then
    # comparing with 2 because the pipeline to compute register-ecom-universal-login.sh count
    # causes extra instances to appear in ps -A; no clue why, but best guess is
    # any commands run from a script show up in ps -A with the name
    # of the parent.
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=RegisterEcomAlreadyRunning"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/RegisterEcomAlreadyRunning"
    exit 1
fi

DOCK_SERIAL="$(/bin/cat /etc/etm-serial)"
if [[ -z "${DOCK_SERIAL}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=SerialNumberEmpty"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/SerialNumberEmpty"
    exit 1
fi

ECOM_AGENCY_DOMAIN=$(load_login_config domain) || { echo "ERR:1/EcomDomainLoadFailed"; exit 1; }
ECOM_ACCESS_TOKEN=$(load_login_config access_token) || { echo "ERR:1/AccessTokenLoadFailed"; exit 1; }

# TASER_DEVICE_TYPE and TASER_DEVICE_MODEL are defined in /etm/bin/etm-common.sh
ECOM_ADMIN_OUT="$(echo "${ECOM_ACCESS_TOKEN}" | /etm/bin/ecom-admin U "${ECOM_AGENCY_DOMAIN}" "${TASER_DEVICE_TYPE}" "${TASER_DEVICE_MODEL}" "${DOCK_SERIAL}")"
if [[ $? -ne 0 ]]; then
    # parse ERR code (if any)
    ECOM_ADMIN_ERR=$(echo "${ECOM_ADMIN_OUT}" | /usr/bin/xargs | /bin/grep -oe "ERR:[0-9]*/" | /bin/grep -oe "[0-9]*")
    if [[ ! -z "${ECOM_ADMIN_ERR}" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAdminRegisterDeviceFailed Output=\"${ECOM_ADMIN_OUT}\""
        # register-ecom-universal-login.lua needs error code and message, it reads it from standard output
        echo "${ECOM_ADMIN_OUT}"
        exit 1
    fi
fi

# split results in a positional parameters
# No double quotes around ECOM_ADMIN_OUT, otherwise it will be interpreted as a single parameter
set -- junk ${ECOM_ADMIN_OUT}
# get rid of junk
shift

ECOM_DEV_ID="$1"
if [[ -z "${ECOM_DEV_ID}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomDevIdEmpty"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomDevIdEmpty"
    exit 1
fi
shift

ECOM_ACCESS_KEY="$1"
ECOM_SECRET_KEY="$2"
if [[ -z "${ECOM_ACCESS_KEY}" ]] || [[ -z "${ECOM_SECRET_KEY}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAuthEmpty"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAuthEmpty"
    exit 1
fi
shift
shift

ECOM_AGENCY_ID="$1"
if [[ -z "${ECOM_AGENCY_ID}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAgencyIdEmpty"
    # register-ecom-universal-login will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAgencyIdEmpty"
    exit 1
fi
shift

ECOM_AGENCY_NAME="$@"
if [[ -z "${ECOM_AGENCY_NAME}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAgencyNameEmpty"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAgencyNameEmpty"
    exit 1
fi

# save to /etc/config/etm
# saving sensitive information, so calling uci directly
if (/sbin/uci set etm.operation.mode="agency" &&
   /sbin/uci set etm.operation.agency_domain="${ECOM_AGENCY_DOMAIN}" &&
   /sbin/uci set etm.operation.access_key="${ECOM_ACCESS_KEY}" &&
   /sbin/uci set etm.operation.secret_key="${ECOM_SECRET_KEY}" &&
   /sbin/uci set etm.operation.authenticated="1" &&
   /sbin/uci set etm.etm.agency="${ECOM_AGENCY_NAME}" &&
   /sbin/uci set etm.operation.agency="${ECOM_AGENCY_NAME}" &&
   /sbin/uci set etm.operation.agency_id="${ECOM_AGENCY_ID}" &&
   /sbin/uci commit etm) ; then
    # Success!
    log_info_msg_no_echo "${SCRIPT_NAME}" "Event=EcomRegistrationAndAuthSaved"
    # register-ecom-universal-login.lua will read this message and interpret as a success
    echo "DONE:register-ecom-universal-login.sh"
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomRegistrationAndAuthSaveFailed"
    # register-ecom-universal-login.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomRegistrationAndAuthSaveFailed" 
    exit 1
fi
