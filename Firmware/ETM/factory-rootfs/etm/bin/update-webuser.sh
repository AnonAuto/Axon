#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2015 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: update-webuser.sh <WEB_ADMIN_USER> <WEB_ADMIN_PASSWD>
#
# Utility script to change username and password for dock's administration webpage.
#

. /etm/bin/etm-common.sh

SCRIPT_NAME="update-webuser.sh"

if [ "$#" -ne 2 ]; then
    echo ""
    echo " Utility script to change username and password for Web UI" >&2
    echo "   Usage: ${SCRIPT_NAME} <WEB_ADMIN_USER> <WEB_ADMIN_PASSWD>" >&2
    echo ""
    exit 1
fi

REALM="SecureUsers"
WEB_ADMIN_USER="$1"
WEB_ADMIN_PASSWD="$2"

HASH="$(echo -n "${WEB_ADMIN_USER}:${REALM}:${WEB_ADMIN_PASSWD}" | /usr/bin/md5sum | cut -b -32)"

/sbin/uci set etm.etm.web_admin_user="${WEB_ADMIN_USER}"
/sbin/uci commit etm

echo "${WEB_ADMIN_USER}:${REALM}:${HASH}" > /etc/lighttpd.user.digest
# Only print first 16 chars of hash
log_info_msg "${SCRIPT_NAME}" "Event=UpdateWebAdmin Hash=${HASH:0:16}****************"
