#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2017 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage: get-header.sh
#

############################ READ THIS WARNING!!!!!!!!!!!!###########
# This script reads etm UCI configuration file, prints out only values that should be sent to the web UI for the header.
# DO NOT send all values to the web UI. Only transmit values that are essential. All data items transmitted here are
# visible to the customer/hacker/security researcher. So, instead of deleting items that should not be sent, rather
# pick each item that should be sent.

# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

SCRIPT_NAME="get-header.sh"

# input uci config file
UCI_CFG="/etc/config/etm"

UCI_CFG_OUT="$(/sbin/uci show ${UCI_CFG} 2> /dev/null)"
if [[ -z "${UCI_CFG_OUT}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciCfgReadFailed UciCfg='${UCI_CFG}'"
    exit 1
fi

# some lines e.g. etm.etm.location can contain spaces, so using newline as a divider
# in the following loop
IFS=$'\n'
for LINE in ${UCI_CFG_OUT} ; do
    # choose/list specific lines/items that are necessary to be transmitted to the UI. Read WARNING on top of file.
    # DO NOT send all UCI configuration values.
    case "${LINE}" in
        etm.etm.location*    | \
        etm.etm.device_home* | \
        etm.etm.name*        | \
        etm.etm.agency*      | \
        etm.etm.version*     )
            echo "${LINE}";;
    esac
done

echo "etm.etm.serial_num=$(cat /etc/etm-serial)"
