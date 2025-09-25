#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script unmounts any devices in the ETM mount folder
#

. /etm/bin/etm-common.sh

MOUNT_DIR=/mnt/etm

# log one line to syslog with the priority given
syslog_line() {
    local PRIORITY=$1
    local MSG=$2
    logger -s -p $PRIORITY -t "umount-camera" "$MSG"
}

RUN_COUNT=$(ps -A | grep unmount-camera-devices.sh | wc -l)

# why 2? 
# because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
# no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
if [ $RUN_COUNT -gt 2 ]; then
    log_info "unmount-camera-devices.sh already running, exiting..."
    exit 2
fi

syslog_line daemon.info "Unmounting any cameras..."

mount | grep "/mnt/etm" | awk '{print $3}' | while read LINE; do
    if [ ! -z $LINE ]; then
        syslog_line daemon.info "unmounting camera at $LINE"
        umount ${LINE}
    fi
done

# remove mount folders, cleanliness...
rm -rf /mnt/etm/*


