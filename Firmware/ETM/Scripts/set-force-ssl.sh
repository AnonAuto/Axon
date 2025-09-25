#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: set-force-ssl.sh CFG_FILE_EXTENSION
#   CFG_FILE_EXTENSION - must be "nossl" or "sslonly"
#
# Depending on command line option replaces /etc/lighttpd.conf with one of the master files:
#   lighttpd.conf.master.nossl or lighttpd.conf.master.sslonly

. /etm/bin/etm-common.sh

SCRIPT_NAME="set-force-ssl.sh"

CFG_FILE_EXTENSION="$1"

if [[ "${CFG_FILE_EXTENSION}" != "nossl" ]] && [[ "${CFG_FILE_EXTENSION}" != "sslonly" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=BadCfgFileExtension"
    exit 1
fi

CFG_FILE_MASTER="/etc/lighttpd.conf.master.${CFG_FILE_EXTENSION}"
CFG_FILE="/etc/lighttpd.conf"

if [[ -f ${CFG_FILE_MASTER} ]]; then
    # replace current lighttpd.conf with requested conf file
    if /bin/cp ${CFG_FILE_MASTER} ${CFG_FILE} ; then
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=LighttpdCfgUpdated Master=${CFG_FILE_MASTER}"
        exit 0
    else
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=LighttpdCfgUpdateFailed"
        exit 1
    fi
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=CfgMasterNotFound Master=${CFG_FILE_MASTER}"
    exit 1
fi
