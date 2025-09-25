#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script watches syslog and unmounts any 
# drives that throw a FAT error.  This usually 
# means the drive was lost, but the mount remained
# behind.
#

# test code, don't delete
#if [ "$1" == "test" ]; then
#    TEST1="Feb 16 02:20:24 taser-etmv2 user.err kernel: [  444.506622] FAT-fs (sdb1): Directory bread(block 3866) failed"
#    TEST2="Feb 16 02:20:24 taser-etmv2 user.err kernel: [11444.506622] FAT-fs (sdc1): Directory bread(block 3866) failed"
#    TEST3="Feb 16 02:20:24 taser-etmv2 user.err kernel: [114441.06622] FAT-fs (sdd1): Directory bread(block 3866) failed"
#    TEST4="Feb 16 02:20:24 taser-etmv2 user.err kernel: [114441.106622] FAT-fs (sde1): Directory bread(block 3866) failed"
#    TEST5="Apr 24 22:14:02 taser-etmv2 user.err kernel: [ 1023.375610] FAT-fs (sdf1): FAT read failed (blocknr 580)"
#    TEST6="Apr 24 22:14:02 taser-etmv2 user.err kernel: [11023.381225] FAT-fs (sdg1): FAT read failed (blocknr 580)"
#    TEST7="Apr 24 22:14:02 taser-etmv2 user.err kernel: [111023.386810] FAT-fs (sdh1): FAT read failed (blocknr 580)"
#    TEST8="Oct 16 16:09:55 taser-etmv2 user.err kernel: [170173.680358] FAT-fs (sdi1): error, invalid access to FAT (entry 0xa4103127)"
#    MNT_DRIVE=$(echo "${TEST1}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST1" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdb1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST2}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST2" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdc1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST3}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST3" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdd1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST4}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST4" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sde1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST5}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST5" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdf1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST6}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST6" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdg1" ]; then echo Test Failed!; fi
#    MNT_DRIVE=$(echo "${TEST7}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST7" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdh1" ]; then echo Test Failed!; fi
#    exit 1;
#    MNT_DRIVE=$(echo "${TEST8}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
#    echo "$TEST8" '=>' ${MNT_DRIVE}
#    if [ "$MNT_DRIVE" != "sdi1" ]; then echo Test Failed!; fi
#    exit 1;
#fi

. /etm/bin/etm-common.sh

MOUNT_DIR=/mnt/etm
SCRIPT_NAME=unmount-missing-devices.sh

do_unmounts() {
    local ERRSTR_FAT="$1"
    local MESSAGE="$2"
    
    grep -e "${ERRSTR_FAT}" "${SYSLOG_TMPFS_FILE}" > /dev/null 2>&1
    if [ $? == "0" ]; then
        log_info_msg  ${SCRIPT_NAME} "${MESSAGE}"
    
        grep "${ERRSTR_FAT}" "${SYSLOG_TMPFS_FILE}" | while read LINE; do
            # example line:
            #  1   2  3          4           5       6     7     8         9      10
            # Feb 16 02:20:24 taser-etmv2 user.err kernel: [  444.506622] FAT-fs (sdb1): Directory bread(block 3866) failed"
            # sometimes the timestamp is long enough that there is no gap between 7 & 8
            # Feb 16 02:20:24 taser-etmv2 user.err kernel: [11444.506622] FAT-fs (sdb1): Directory bread(block 3866) failed"
            MNT_DRIVE=$(echo "${LINE}" | sed -n 's:^.*(\(sd..\)).*$:\1:p')
            MNT_PATH=$(mount | grep "/dev/${MNT_DRIVE}" | awk '{print $3}')
            if [ ! -z $MNT_PATH ]; then
                log_err_msg  ${SCRIPT_NAME} "unmounting $MNT_DRIVE from $MNT_PATH"
                if ! umount ${MNT_PATH}; then
                    log_err_msg  ${SCRIPT_NAME} "error unmounting $MNT_DRIVE from $MNT_PATH"
                    exit 1
                fi
            fi
        done
    fi
}

# limit to one instance
RUN_COUNT=$(ps -A | grep unmount-missing-devices.sh | wc -l)

# why 2? 
# because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
# no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
if [ $RUN_COUNT -gt 2 ]; then
    log_info "unmount-missing-devices.sh already running, exiting..."
    exit 2
fi

do_unmounts "FAT.*: Directory bread.*failed" "FAT Error detected (Dir), scanning mounts..."
do_unmounts "FAT.*: FAT read failed" "FAT Error detected (Read), scanning mounts..."
do_unmounts "FAT.*: error, invalid access to FAT" "FAT Error detected (Access), scanning mounts..."
