#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: echo "ECOM_ADMIN_USER:ECOM_PASSWORD" | register-ecom.sh ECOM_AGENCY_DOMAIN
#   ECOM_AGENCY_DOMAIN - E.com agency domain, must be fully specified, i.e.
#                        agency.evidence.com
#   ECOM_ADMIN_USER    - ECOM_AGENCY_DOMAIN user name with admin permissions
#   ECOM_PASSWORD      - password for ECOM_ADMIN_USER
#
# Registers this dock on E.com then saves registration information to etm UCI configuration file.


. /etm/bin/etm-common.sh

SCRIPT_NAME="register-ecom.sh"

# make sure that only one instance of this script is running
if [[ "$(/bin/ps -A 2>/dev/null | /bin/grep register-ecom.sh | /usr/bin/wc -l)" -gt 2 ]]; then
    # comparing with 2 because the pipeline to compute register-ecom.sh count
    # causes extra instances to appear in ps -A; no clue why, but best guess is
    # any commands run from a script show up in ps -A with the name
    # of the parent.
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=RegisterEcomAlreadyRunning"
    # register-ecom.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/RegisterEcomAlreadyRunning"
    exit 1
fi

ECOM_AGENCY_DOMAIN="$1"
if [[ -z "${ECOM_AGENCY_DOMAIN}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AgencyDomainEmpty"
    # register-ecom.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/AgencyDomainEmpty"
    exit 1
fi

DOCK_SERIAL="$(/bin/cat /etc/etm-serial)"
if [[ -z "${DOCK_SERIAL}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=SerialNumberEmpty"
    # register-ecom.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/SerialNumberEmpty"
    exit 1
fi

# IFS= disables interpretation of spaces, without it leading and trailing spaces will be trimmed
# -s means secure mode, so no echo output to the console
# -r means raw input - disables interpretion of backslash escapes and line-continuation in the read data
# More info: http://wiki.bash-hackers.org/commands/builtin/read
IFS= read -s -r ECOM_AUTH
# submit ecom-admin register-device command, on success it completes with 0 and
# on success returns a string similar to:
#   Authentication: dv-d6d0912b85624a0b8dcbc50dddea4c26
# on failure:
#   Authentication: ERR:150/Invalid required values
#
# TASER_DEVICE_TYPE and TASER_DEVICE_MODEL are defined in /etm/bin/etm-common.sh
ECOM_ADMIN_OUT="$(echo "${ECOM_AUTH}" | /etm/bin/ecom-admin r "${ECOM_AGENCY_DOMAIN}" "${TASER_DEVICE_TYPE}" "${TASER_DEVICE_MODEL}" "${DOCK_SERIAL}")"
if [[ $? -ne 0 ]]; then
    # parse ERR code (if any)
    ECOM_ADMIN_ERR=$(echo "${ECOM_ADMIN_OUT}" | /usr/bin/xargs | /bin/grep -oe "ERR:[0-9]*/" | /bin/grep -oe "[0-9]*")
    # 1080 - the server thinks this Dock has been registered before, since
    # we might have it wrong in our local copy (DOCK-917)
    if [[ ! -z "${ECOM_ADMIN_ERR}" ]] && [[ "${ECOM_ADMIN_ERR}" != "1080" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAdminRegisterDeviceFailed Output=\"${ECOM_ADMIN_OUT}\""
        # register-ecom.lua needs error code and message, it reads it from standard output
        echo "${ECOM_ADMIN_OUT}"
        exit 1
    fi
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

# get agency name and partner ID for ECOM_AGENCY_DOMAIN
# on success returns string similar to:
#  a3d1210c818541c3808f164a4387418c dogfoodsb
# on failure:
#  ERR:100006/SSL handshake failed
# or
#  ERR:1060/booooo.evidence.com is not a valid hostname
ECOM_ADMIN_OUT="$(/etm/bin/ecom-admin a ${ECOM_AGENCY_DOMAIN})"
if [[ $? -ne 0 ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAdminAgencyIdFailed Output=\"${ECOM_ADMIN_OUT}\""
    # register-ecom.lua needs error code and message, it reads it from standard output
    echo "${ECOM_ADMIN_OUT}"
    exit 1
fi

# split results in a positional parameters
# No double quotes around ECOM_ADMIN_OUT, otherwise it will be interpreted as a single parameter
set -- junk ${ECOM_ADMIN_OUT}
# get rid of junk
shift
ECOM_AGENCY_ID="$1"
shift
ECOM_AGENCY_NAME="$@"

if [[ -z "${ECOM_AGENCY_ID}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAgencyIdEmpty"
    # register-ecom.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAgencyIdEmpty"
    exit 1
fi

if [[ -z "${ECOM_AGENCY_NAME}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomAgencyNameEmpty"
    # register-ecom.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomAgencyNameEmpty"
    exit 1
fi

# save configuration to /etc/config/etm
# saving sensitive information, so calling uci directly
if (/sbin/uci set etm.etm.agency="${ECOM_AGENCY_NAME}" &&
   /sbin/uci set etm.operation.agency="${ECOM_AGENCY_NAME}" &&
   /sbin/uci set etm.operation.agency_domain="${ECOM_AGENCY_DOMAIN}" &&
   /sbin/uci set etm.operation.agency_id="${ECOM_AGENCY_ID}" &&
   /sbin/uci commit etm) ; then
    # Success!
    log_info_msg_no_echo "${SCRIPT_NAME}" "Event=EcomRegistrationSaved"
    # get-keys.lua will read this message and interpret as a success
    echo "DONE:register-ecom.sh"
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=EcomRegistrationSaveFailed"
    # get-keys.lua will read this message, parse it and pass it to the WebUI
    echo "ERR:1/EcomRegistrationSaveFailed" 
    exit 1
fi
