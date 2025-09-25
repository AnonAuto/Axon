#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: sync-etm-log.sh
#
# Syncronize log files which were saved on tmpfs memory partition with 
# log directory on SD card

. /etm/bin/etm-common.sh

# check if the test mode is set
TEST_MODE=0
if [ "$1" == "test" ]; then
    TEST_MODE=1
fi

collect_data_then_rm_src() {
    # take all data from the SRC file and append it to the DST file, then
    # remove the SRC; this function returns 1 (error) if it's unable to save
    # data in the DST file or remove the SRC, otherwise it returns 0
    local SRC="$1"
    local DST="$2"

    if [[ -f "${SRC}" ]]; then
        if ! cat "${SRC}" >> "${DST}" ; then
            echo "ERROR collect_data_then_rm_src(): failed to copy data from'${SRC}' to '${DST}'" >&2
            return 1
        fi

        if ! rm -f "${SRC}" ; then 
            echo "ERROR collect_data_then_rm_src(): failed to remove '${SRC}'" >&2
            return 1
        fi
    else
        echo "WARNING collect_data_then_rm_src(): can't find SRC file ${SRC}" >&2
    fi

    return 0
}

collect_data_then_erase_src() {
    # take all data from the SRC file and append it to the DST file, then
    # erase (remove all data from the file and leave the empty file) the SRC;
    # this function returns 1 (error) if it's unable to save data in the DST
    # file or erase the SRC, otherwise it returns 0
    local SRC="$1"
    local DST="$2"

    if [[ -f "${SRC}" ]]; then
        if ! cat "${SRC}" >> "${DST}" ; then
            echo "ERROR collect_data_then_erase_src(): failed to copy data from'${SRC}' to '${DST}'" >&2
            return 1
        fi

        if ! echo -n "" > "${SRC}" ; then
            echo "ERROR collect_data_then_erase_src(): failed to erase '${SRC}'" >&2
            return 1
        fi
    else
        echo "WARNING collect_data_then_erase_src(): can't find SRC file ${SRC}" >&2
    fi

    return 0
}

sync_syslog() {
    # sync syslog logs; this function returns 1 (error) if it's unable to sync logs,
    # otherwise it returns 0

    local RC=0

    # unlikely syslog file will exceed its rotation threshold between two log syncs,
    # but just in case...
    if [[ -f "${SYSLOG_TMPFS_ROT0}" ]]; then
        # there is '-f' test in collect_data_then_rm_src(), but testing here for existence of
        # SYSLOG_TMPFS_ROT0 file allows to omit warnings, because in 99.9999% of cases it doesn't exist
        if ! collect_data_then_rm_src "${SYSLOG_TMPFS_ROT0}" "${SYSLOG_FILE}.${OUT_FILENAME_TS}" ; then
            RC=1
        fi 
    else
        echo "INFO sync_syslog(): there is no ${SYSLOG_TMPFS_ROT0}, so doesn't sync it"
    fi

    if ! collect_data_then_erase_src "${SYSLOG_TMPFS_FILE}" "${SYSLOG_FILE}.${OUT_FILENAME_TS}" ; then
        RC=1
    fi

    return ${RC}
}

sync_etmd_log() {
    # sync etmd log files; this function returns 1 (error) if it fails to
    # synchronize etmd log files, otherwise it returns 0; please note that
    # if there are no etmd.log.* files for sync this function will print
    # a warning message and will return 0
    #
    # please note: there is ETMD_LOG_PREFIX constant defined in etmd sources
    # in main.cpp; this constant defines etmd log filename prefix, which is 'etmd.log',
    # so if you change code here, please make sure that etmd will get all required
    # updates, otherwise etmd logs sync will be broken

    local RC=0

    # get the list of all etmd.log.* files in ${TMPFS_LOG_DIR} directory;
    # using find and sort to get all files (and the log records) in the right order,
    # but even if the order is wrong - splunk will fix it; in case if somebody
    # rewind the clock we can use syslog to detect this event and recover from it
    local ETMD_LOG_FILES=$(find "${TMPFS_LOG_DIR}" -name "etmd.log.*" -type f 2>/dev/null | LC_ALL="C" sort -s)

    if [[ ! -z "${ETMD_LOG_FILES}" ]]; then
        # etmd uses SIGUSR1 Posix signal as a command to release its current
        # log file, and open a new one etmd.log.yymmdd.hhmmss, so tell etmd
        # to release its current log file
        killall -s USR1 etmd

        # give it some time to complete everything
        sleep 5

        # get the name of current active log file; etmd may be busy and processing of the signal may take
        # more time than expected, in this case we need to get the name of current active log file to
        # ignore it
        local ETMD_ACTIVE_LOG=$(lsof 2>/dev/null | grep "etmd" | grep "${TMPFS_LOG_DIR}" | awk '{print $3;}')
        if [[ -z "${ETMD_ACTIVE_LOG}" ]]; then
            echo "WARNING sync_etmd_log(): can't find current active etmd log file" >&2
        fi

        for i in ${ETMD_LOG_FILES} ; do
            if [[ "${i}" != "${ETMD_ACTIVE_LOG}" ]]; then
                if ! collect_data_then_rm_src "${i}" "${ETMLOG_FILE}.${OUT_FILENAME_TS}" ; then
                    RC=1
                fi
            fi
        done
    else
        echo "WARNING sync_etmd_log(): no etmd.log.* files found in ${TMPFS_LOG_DIR}" >&2
    fi

    return ${RC}
}

sync_lighttpd_log() { 
    # sync lighttpd logs; this function returns 1 (error) if it's unable to sync logs,
    # otherwise it returns 0
    local RC=0

    # synchronize lighttpd logs
    # lighttpd logs may be empty because there was no activity , so save some I/O cycles and don't sync empty logs
    if [[ -s "${LIGHTTPD_TMPFS_LOG_ACCESS}" ]]; then
        if ! collect_data_then_erase_src "${LIGHTTPD_TMPFS_LOG_ACCESS}" "${LIGHTTPD_LOG_ACCESS}.${OUT_FILENAME_TS}" ; then
            RC=1
        fi
    else
        echo "INFO sync_lighttpd_log(): skipping empty ${LIGHTTPD_TMPFS_LOG_ACCESS}"
    fi

    if [[ -s "${LIGHTTPD_TMPFS_LOG_ERROR}" ]]; then
        if ! collect_data_then_erase_src "${LIGHTTPD_TMPFS_LOG_ERROR}" "${LIGHTTPD_LOG_ERROR}.${OUT_FILENAME_TS}" ; then
            RC=1
        fi
    else
        echo "INFO sync_lighttpd_log(): skipping empty ${LIGHTTPD_TMPFS_LOG_ERROR}"
    fi

    if [[ -s "${LIGHTTPD_TMPFS_LOG_BREAKAGE}" ]]; then
        if ! collect_data_then_erase_src "${LIGHTTPD_TMPFS_LOG_BREAKAGE}" "${LIGHTTPD_LOG_BREAKAGE}.${OUT_FILENAME_TS}"; then
            RC=1
        fi
    else
        echo "INFO sync_lighttpd_log(): skipping empty ${LIGHTTPD_TMPFS_LOG_BREAKAGE}"
    fi

    return ${RC}
}

# make sure that only one instance of this script is running
if [[ "$(ps -A 2>/dev/null | grep sync-etm-log.sh | wc -l)" -gt 2 ]]; then
    # comparing with 2 because the pipeline to compute sync-etm-log.sh count causes
    # extra instances to appear in ps -A; no clue why, but best guess is any commands
    # run from a script show up in ps -A with the name of the parent.
    echo "ERROR: sync-etm-log.sh is already running, exiting..." >&2
    exit 2
fi

# get current yymmdd.HHMMSS date/time stamp, where:
#   yy - two last digits of the current year [00 - 99]
#   mm - two digits for current month [01 - 12]
#   dd - two digits for current day [01 - 31]
#   HH - two digits for current hour in 24h format [00 - 23]
#   MM - two digits for current minute [00 - 59]
#   SS - two digits for current second [00 - 59]
OUT_FILENAME_TS="$(date +%y%m%d.%H%M%S 2>/dev/null)"
if [[ -z "${OUT_FILENAME_TS}" ]]; then
    # it's almost impossible for date to fail but just in case,
    # set current timestamp with all zeros on failure
    OUT_FILENAME_TS="000000.000000"
    echo "WARNING: unable to get current date/time stamp for logs sync, using 000000.000000" >&2
fi

# save it to the temporary file
if ! echo "${OUT_FILENAME_TS}" > "${LOGS_SYNC_OUT_FILENAME_TS_FILE}" ; then
    echo "WARNING: unable to save current timestamp to ${LOGS_SYNC_OUT_FILENAME_TS_FILE}" >&2
fi

# for test mode - inject a delay long enough to ensure we can launch multiple instances at the same
# time before the first one exits; it's important to place the delay here for other tests that
# should be able to read timestamp from ${LOGS_SYNC_OUT_FILENAME_TS_FILE}
if [[ "${TEST_MODE}" == "1" ]] ; then
    # parameter validation: ${2##*[!0-9]*} returns an empty string if $2 contains anything except digits
    if [[ ! -z "${2##*[!0-9]*}" ]] ; then 
        sleep "$2"
    else
        # remove the temporary file
        rm -f "${LOGS_SYNC_OUT_FILENAME_TS_FILE}"
        echo "ERROR: test mode requres an additional integer parameter - delay in seconds"
        exit 1
    fi
fi

RC=0

# sync log files
if ! sync_syslog ; then
    echo "WARNING: syslog sync completed with issues" >&2
    RC=1
fi

if ! sync_etmd_log ; then
    echo "WARNING: etmd logs sync completed with issues" >&2
    RC=1
fi

if ! sync_lighttpd_log ; then
    echo "WARNING: lighttpd logs sync completed with issues" >&2 
    RC=1
fi

# remove the temporary file
rm -f "${LOGS_SYNC_OUT_FILENAME_TS_FILE}"

exit ${RC}
