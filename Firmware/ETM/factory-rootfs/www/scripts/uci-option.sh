#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: uci-option.sh set/delete UCI_KEY [VALUE]
#
# Set or deletes value of specified key to etm UCI configuration file.
# Please note that to make changes active uci-commit-etm.sh must be called.
# Ex: uci-option.sh set etm.etm.name myname
#     uci-option.sh delete etm.etm.agency
#
# !!!Warning!!! Do not echo anything in this or subsequent calling scripts as that may result in getting send back to UI

. /etm/bin/etm-common.sh

SCRIPT_NAME="uci-option.sh"

ACTION="$1" # should be set or delete
UCI_KEY="$2"
VALUE="$3"

if [[ "${ACTION}" != "set" ]] && [[ "${ACTION}" != "delete" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidAction Action=${ACTION}"
    exit 1
fi

if [[ -z "${UCI_KEY}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciKeyEmpty"
    exit 1
fi

if [[ "${ACTION}" == "set" ]] && [[ -z "${VALUE}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciValueEmpty"
    exit 1
fi

# ensure that UCI_KEY is the one that user is allowed to change
if [[ "${UCI_KEY}" == "etm.etm.agency" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.name" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.location" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.device_home" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.ecom_sync" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.web_admin_user" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.require_https_time" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.accept_only_https" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.netlimit_kbitps" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.enable_snmp" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.snmp_user" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.snmp_auth" ]] ||
   [[ "${UCI_KEY}" == "etm.etm.snmp_encrypt" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.enabled" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.host" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.port" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.encrypted_un" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.encrypted_pw" ]] ||
   [[ "${UCI_KEY}" == "etm.proxy.disable_dns_check" ]]; then
    if ! /sbin/uci set "${UCI_KEY}"="${VALUE}" ; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciSetFailed Key=${UCI_KEY} Value=${VALUE} Action=${ACTION}"
        exit 1
    fi
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciKeyProtected Key=${UCI_KEY} Action=${ACTION}"
    exit 1
fi
