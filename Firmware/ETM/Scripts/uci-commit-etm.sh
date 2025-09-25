#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: uci-commit-etm.sh
#
# Commits all changes to etm UCI config file

. /etm/bin/etm-common.sh

SCRIPT_NAME="uci-commit-etm.sh"

if ! /sbin/uci commit etm ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciEtmCommitFailed"
    exit 1
fi

log_info_msg_no_echo "${SCRIPT_NAME}" "Event=UciEtmCommitted"
