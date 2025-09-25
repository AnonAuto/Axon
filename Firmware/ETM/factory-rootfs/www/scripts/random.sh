#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: random.sh
#
# This script uses openssl to return a 24 byte random number in base64
#

. /etm/bin/etm-common.sh

SCRIPT_NAME="random.sh"

RANDOM_OUTPUT="$(/usr/bin/openssl rand -base64 24)"

if [[ -z "${RANDOM_OUTPUT}" ]]; then
   log_err_msg_no_echo "${SCRIPT_NAME}" "Event=RandomFailed"
   exit 1
fi

echo -n "${RANDOM_OUTPUT}"
