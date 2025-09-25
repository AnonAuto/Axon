#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: truncate-etm-log.sh
#
# force etmd to truncate it's log by stopping and restarting the etm 
# and watchdog services

# load our common functions, including UCI file support
. /etm/bin/etm-common.sh
THIS_SCRIPT=truncate-etm-logs.sh
# ~ 30 MB
MAX_SIZE_ETMD=30000000
# ~ 10 MB
SHRINK_SIZE_ETMD=10000000
# ~ 5 MB - note that the system log rotator is set
#          to 10MB, which will (hopefully) allow this
#          script to handle the truncation first before
#          rotation is necessary.
#          If etmcrash.sh is running properly, we should
#          never need to truncate.
MAX_SIZE_SYSLOG=5000000
# ~ 1 MB
SHRINK_SIZE_SYSLOG=1000000
# number of lines to keep for LIGHTTPD logs
LIGHTTPD_LOG_SHRINK_LINES=3000

# stopping and starting our services is heavy since it requires reinitializing all the
# cameras and the consequent hits on e.com.  Therefore we only shutdown the etm services
# if necessary.  shutdown and start are in etm-common.sh  These keep track of 
# need to restart
RESTART_LIGHTTPD=0
RESTART_ETM=0

truncate_tail() {
    local LOG="$1"
    local LOG_SIZE=$2
    local LOG_LINES=$3
    local LINES_TO_KEEP=$4

    local LOG_TEMP="${LOG}.temp"
    local LOG_SIZE_MB=$(( LOG_SIZE / 1048576 ))

    # check to make sure there is enough free space...
    # ash will overflow at 2 GB, so we have to do the math in 1kb blocks
    local BLOCKS_FREE=$(df | grep /dev/root | awk '{print $4}')
    local SHRINK_SIZE=$(tail -n ${LINES_TO_KEEP} "${LOG}" | wc -c)
    # multiplying by 2 to allow for slight overage from varying line sizes
    # if we ever get this close to a full disk, something is wrong, so deleting to make space is 
    # reasonable
    local SHRINK_BLOCKS=$(( SHRINK_SIZE / 1024 * 2 ))

    if [ ${SHRINK_BLOCKS} -lt ${BLOCKS_FREE} ]; then
        # go the shrink route...
        log_info_msg "${THIS_SCRIPT}" "Log ${LOG} too large (~${LOG_SIZE_MB} MB). Shrinking from ${LOG_LINES} to ${LINES_TO_KEEP}"
        tail -n ${LINES_TO_KEEP} "${LOG}" > "${LOG_TEMP}"
        rm -f "${LOG}"
        mv "${LOG_TEMP}" "${LOG}"
    else
        # just delete the log outright...
        log_info_msg "${THIS_SCRIPT}" "Log ${LOG} too large (~${LOG_SIZE_MB} MB).  No space for shrink, deleting instead"
        send_critical_alert "${THIS_SCRIPT}" "delete_log_low_space log=${LOG}"
        rm -f "${LOG}"
    fi
}

truncate_size() {
    # truncate the file to SHRINK_SIZE if it is at least MAX_SIZE.
    local LOG="$1"
    local MAX_SIZE=$2
    local SHRINK_SIZE=$3

    if [ ${SHRINK_SIZE} -gt ${MAX_SIZE} ]; then
        SHRINK_SIZE=${MAX_SIZE}
    fi
    
    if [ -f "${LOG}" ]; then
        # truncate logs if they are too large.  Here we discard the
        # oldest parts of the logs by using tail.  We compute the 
        # number of lines to tail by the ratio of size to desired size.
        # This is only approximate, but it keeps the recent data we want and 
        # is easy to implement and verify.
        local WC=$(wc "${LOG}")
        local SIZE=$(echo "${WC}" | awk '{print $3}')
        local LINES=$(echo "${WC}" | awk '{print $1}')
        # figure out number of lines to keep
        if [ ${SIZE} -gt ${MAX_SIZE} ]; then
            # this calculation is in this form to avoid overflow or 
            # integer truncation, so don't attempt to rewrite it as the 
            # "simpler" mathematical equivalents: 
            # SHRINK / SIZE * LINES or LINES * SHRINK / SIZE
            local LINES_TO_KEEP=$(( SHRINK_SIZE * 100 / SIZE * LINES / 100 ))

            truncate_tail "${LOG}" "${SIZE}" "${LINES}" "${LINES_TO_KEEP}"
        fi
    fi
}

truncate_lines() {
    local LOG="$1"
    local LINES_TO_KEEP=$2

    if [ -f "${LOG}" ]; then
        # Truncate logs if they are too large. Here we discard the
        # oldest parts of the logs using tail and number of lines to keep.
        local WC=$(wc "${LOG}")
        local SIZE=$(echo "${WC}" | awk '{print $3}')
        local LINES=$(echo "${WC}" | awk '{print $1}')
        if [ ${LINES} -gt ${LINES_TO_KEEP} ]; then
            truncate_tail "${LOG}" "${SIZE}" "${LINES}" "${LINES_TO_KEEP}"
        fi
    fi
}

test_file_size() {
    # truncate the file to SHRINK_SIZE if it is at least MAX_SIZE.
    local LOG="$1"
    local MAX_SIZE=$2
    local RETURN=0
    
    if [ -f "${LOG}" ]; then
        local WC=$(wc "${LOG}")
        local SIZE=$(echo "${WC}" | awk '{print $3}')
        
        # figure out number of lines to keep
        if [ ${SIZE} -le ${MAX_SIZE} ]; then
            log_info_msg "${THIS_SCRIPT}" "Log size ok for ${LOG}"
        else
            RETURN=1
        fi
    fi
    return ${RETURN}
}

test_file_lines() {
    local LOG="$1"
    local MAX_LINES=$2
    local RETURN=0

    if [ -f "${LOG}" ]; then
        # Truncate logs if they are too large. Here we discard the
        # oldest parts of the logs using tail and number of lines to keep. 
        local WC=$(wc "${LOG}")
        local LINES=$(echo "${WC}" | awk '{print $1}')

        if [ ${LINES} -le ${MAX_LINES} ]; then
            log_info_msg "${THIS_SCRIPT}" "Log size ok for ${LOG}"
        else
            RETURN=1 
        fi
    fi
    return ${RETURN}
}

warn_disk_usage() {
    USED=$(df | grep root |  awk '{print $5}' | cut -d% -f1)
    BLOCKS_TOTAL=$(df | grep root |  awk '{print $2}' )
    SIZE=$((BLOCKS_TOTAL / 1024))
    
    # the ETM should never get close to 70% disk usage.  If it does, something is amiss, start issuing warnings.
    if [ $USED -ge 70 ]; then
        send_critical_alert "${THIS_SCRIPT}" "critical_disk_usage: free_pct=${USED} total_mb=${SIZE}."
    fi
}

# don't worry about data loss in these files, so truncate them without stopping services.
truncate_lines "${RESTART_DEBUG}" 10000
truncate_lines "${REBOOT_DEBUG}" 10000

if ! test_file_lines "${LIGHTTPD_LOG_ACCESS}" "${LIGHTTPD_LOG_SHRINK_LINES}" || \
   ! test_file_lines "${LIGHTTPD_LOG_BREAKAGE}" "${LIGHTTPD_LOG_SHRINK_LINES}" || \
   ! test_file_lines "${LIGHTTPD_LOG_ERROR}" "${LIGHTTPD_LOG_SHRINK_LINES}"; then

   shutdown_lighttpd
   RESTART_LIGHTTPD=1
   truncate_lines "${LIGHTTPD_LOG_ACCESS}" "${LIGHTTPD_LOG_SHRINK_LINES}"
   truncate_lines "${LIGHTTPD_LOG_BREAKAGE}" "${LIGHTTPD_LOG_SHRINK_LINES}"
   truncate_lines "${LIGHTTPD_LOG_ERROR}" "${LIGHTTPD_LOG_SHRINK_LINES}"

fi

if ! test_file_size "${ETMLOG_FILE}" "${MAX_SIZE_ETMD}" || \
   ! test_file_size "${SYSLOG_FILE}" "${MAX_SIZE_SYSLOG}"; then
    
    shutdown_etm
    RESTART_ETM=1
    truncate_size "${ETMLOG_FILE}" "${MAX_SIZE_ETMD}" "${SHRINK_SIZE_ETMD}"
    truncate_size "${SYSLOG_FILE}" "${MAX_SIZE_SYSLOG}" "${SHRINK_SIZE_SYSLOG}"
fi

warn_disk_usage

# restart services.  Tests against -NE 0 to bias for a restart to make sure we
# don't wind up with stopped services if it is set to some other non-zero value
# by mistake.
if [ $RESTART_LIGHTTPD -ne 0 ]; then
    start_lighttpd
fi

if [ $RESTART_ETM -ne 0 ]; then
    start_etm
fi

