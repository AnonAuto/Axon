#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script uploads the telemetry logs to e.com
# for analysis.
#
# Current strategy:
#
# Append Syslog.TS1 & Syslog.TS2 to syslog, then append syslog to upload_log;
# Do the same with etmd and lighttpd logs. TS1 & TS2 - timestamped versions of logs
# saved by sync-etm-log.sh.
#
# In the case where upload succeeds, this has one wasteful copy to syslog when the files
# could have been appended to upload_log directly. We decided on this approach to deal
# with the not-unlikely case of the upload failing where the number of pending logs could grow large.
#

# defines a lot of variables, like where the logs are
. /etm/bin/etm-common.sh

SERVICE_NAME=etmcrash.sh

log_info() {
    logger -s -p daemon.info -t ${SERVICE_NAME} "$1"
}

compile_logs() {
    IN_FILES_LIST="$1"
    OUT_FILE="$2"
    FILTERED_FILE="$3"

    for i in ${IN_FILES_LIST} ; do 
        if [[ -z "${FILTERED_FILE}" ]] || [[ "${i}" != "${FILTERED_FILE}" ]]; then
            if ! cat "${i}" >> "${OUT_FILE}" ;then
                log_info "Can't save data from ${i} to ${OUT_FILE}"
            else
                rm -f "${i}"
            fi
        fi
    done
}

# mark script as in progress for watchdog
write_now_timestamp ${SERVICE_NAME} "${ETMCRASH_TS_FILE}"

# 'compile' all timestamped logs saved by sync-etm-log.sh into corresponding files
TS_SYSLOG_FILES=$(find "${LOG_DIR}" -name "syslog.*" -type f 2>/dev/null | LC_ALL="C" sort -s)
TS_ETMD_FILES=$(find "${LOG_DIR}" -name "etmd.log.*" -type f 2>/dev/null | LC_ALL="C" sort -s)
TS_LIGHTTPD_LOG_ACCESS_FILES=$(find "${LOG_DIR}" -name "lighttpd.access.log.*" -type f 2>/dev/null | LC_ALL="C" sort -s)
TS_LIGHTTPD_LOG_ERROR_FILES=$(find "${LOG_DIR}" -name "lighttpd.error.log.*" -type f 2>/dev/null | LC_ALL="C" sort -s)
TS_LIGHTTPD_LOG_BREAKAGE_FILES=$(find "${LOG_DIR}" -name "lighttpd.breakage.log.*" -type f 2>/dev/null | LC_ALL="C" sort -s)

# read current sync filename timestamp (if sync-etm-log.sh is running)
SYNC_FILENAME_TS=

if [[ -f "${LOGS_SYNC_OUT_FILENAME_TS_FILE}" ]]; then
    SYNC_FILENAME_TS="$(cat ${LOGS_SYNC_OUT_FILENAME_TS_FILE} 2>/dev/null)"
fi

if [[ -z "${SYNC_FILENAME_TS}" ]]; then
    # nothing to filter
    compile_logs "${TS_SYSLOG_FILES}" "${SYSLOG_FILE}"
    compile_logs "${TS_ETMD_FILES}" "${ETMLOG_FILE}"
    compile_logs "${TS_LIGHTTPD_LOG_ACCESS_FILES}" "${LIGHTTPD_LOG_ACCESS}"
    compile_logs "${TS_LIGHTTPD_LOG_ERROR_FILES}" "${LIGHTTPD_LOG_ERROR}"
    compile_logs "${TS_LIGHTTPD_LOG_BREAKAGE_FILES}" "${LIGHTTPD_LOG_BREAKAGE}"
else
    # there is sync filename timestamp, don't touch active logs
    compile_logs "${TS_SYSLOG_FILES}" "${SYSLOG_FILE}" "${SYSLOG_FILE}.${SYNC_FILENAME_TS}"
    compile_logs "${TS_ETMD_FILES}" "${ETMLOG_FILE}" "${ETMLOG_FILE}.${SYNC_FILENAME_TS}"
    compile_logs "${TS_LIGHTTPD_LOG_ACCESS_FILES}" "${LIGHTTPD_LOG_ACCESS}" "${LIGHTTPD_LOG_ACCESS}.${SYNC_FILENAME_TS}"
    compile_logs "${TS_LIGHTTPD_LOG_ERROR_FILES}" "${LIGHTTPD_LOG_ERROR}" "${LIGHTTPD_LOG_ERROR}.${SYNC_FILENAME_TS}"
    compile_logs "${TS_LIGHTTPD_LOG_BREAKAGE_FILES}" "${LIGHTTPD_LOG_BREAKAGE}" "${LIGHTTPD_LOG_BREAKAGE}.${SYNC_FILENAME_TS}"
fi

# include the emergency syslog from the watchdog process, if any.
if [ -f ${SYSLOG_EMERG} ]; then
    cat ${SYSLOG_EMERG} >> ${SYSLOG_FILE}
    # then save it in a backup
    if [ -f ${SYSLOG_EMERG}.old ]; then
        rm -f ${SYSLOG_EMERG}.old
    fi
    mv ${SYSLOG_EMERG} ${SYSLOG_EMERG}.old
fi

# Build upload file
rm ${UPLOAD_LOG}
rm ${UPLOAD_LOG}.gz
# First, add debug data to file...
echo "[[[[[  Configuration  ]]]]]" >> ${UPLOAD_LOG}
make_tmp_status_config
cat /tmp/status.config >> ${UPLOAD_LOG}

echo "[[[[[    ETM State    ]]]]]" >> ${UPLOAD_LOG}
cat /tmp/etm.state >> ${UPLOAD_LOG}
echo "" >> ${UPLOAD_LOG}

echo "[[[[[ ETM Reboot Log ]]]]]" >> ${UPLOAD_LOG}
if [ -f ${REBOOT_DEBUG} ]; then
    cat ${REBOOT_DEBUG} >> ${UPLOAD_LOG}
fi
echo "" >> ${UPLOAD_LOG}

echo "[[[[[ ETM Restart Log ]]]]]" >> ${UPLOAD_LOG}
if [ -f ${RESTART_DEBUG} ]; then
    cat ${RESTART_DEBUG} >> ${UPLOAD_LOG}
fi
echo "" >> ${UPLOAD_LOG}

echo "[[[[[ ETM Force Enumeration Log ]]]]]" >> ${UPLOAD_LOG}
if [ -f ${LOG_DIR}/enumerate.debug ]; then
    cat ${LOG_DIR}/enumerate.debug >> ${UPLOAD_LOG}
fi
echo "" >> ${UPLOAD_LOG}

echo "[[[[[ File Corruption ]]]]]" >> ${UPLOAD_LOG}
# corrupt file list created in etmstat.sh
cat /tmp/corruption >> ${UPLOAD_LOG}

# save the syslog in case the upload fails
# if it fails, this log will be replayed back into the archived syslog.
# This solves the problem of truncating later that might miss any messages between now and
# when we would truncate the log at the end of this script.
echo "[[[[[     Syslog      ]]]]]" >> ${UPLOAD_LOG}
if [ -f ${SYSLOG_FILE} ]; then
    cat ${SYSLOG_FILE} >> ${UPLOAD_LOG}
fi

# IMPORTANT!!
# leave this section immediately after syslog.  
# The splunk extractor uses this as a termination mark.
# IMPORTANT!!
echo "[[[[[     UCI State (network) ]]]]]" >> ${UPLOAD_LOG}
cat ${STATE_DIR}/network >> ${UPLOAD_LOG}
echo "[[[[[     UCI State (etm - 50 lines) ]]]]]" >> ${UPLOAD_LOG}
tail -n 50 ${STATE_DIR}/etm >> ${UPLOAD_LOG}

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CAUTION: ETMD Section MUST BE LAST!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Why? Because etm-watchdog.sh extracts the tail of the etmd log for some debugging cases.
# and for expediency expects it to be last.
echo "[[[[[     Etmdlog      ]]]]]" >> ${UPLOAD_LOG}
if [ -f ${ETMLOG_FILE} ]; then
    cat ${ETMLOG_FILE} >> ${UPLOAD_LOG}
fi

# transmit or upload file
config_load etm
config_get VERSION etm version
config_get AGENCY operation agency_domain
SERIAL=$(cat /etc/etm-serial)
if [ -z $SERIAL ]; then
    SERIAL=${DEFAULT_SERIAL}
fi

if [ -z "$AGENCY"  ]; then
    log_info "ETM is not registered"
    RESULT=99
else
    gzip ${UPLOAD_LOG}
    /etm/bin/ecom-admin l $AGENCY ${UPLOAD_LOG}.gz $CRASH_LOG_MODEL $SERIAL $VERSION
    RESULT=$?
fi

if [ $RESULT -ne 0 ]; then
    log_info "Log upload failed, keeping our logs..."
else
    log_info "Log upload complete, resetting our logs..."
    
    # if we are a debug build, keep the logs that were transmitted for easier analysis
    if [ $ETM_DEBUG_BUILD ]; then
        cat ${SYSLOG_FILE} >> ${SYSLOG_DEBUG}
        cat ${ETMLOG_FILE} >> ${ETMLOG_DEBUG}
        USED=$(df | grep root |  awk '{print $5}' | cut -d% -f1)
        if [ $USED -ge 80 ]; then
            log_info "truncating debug logs due to disk space"
            rm -f ${SYSLOG_DEBUG}
            rm -f ${ETMLOG_DEBUG}
        fi
    fi

    rm -f ${SYSLOG_FILE}
    rm -f ${ETMLOG_FILE}
fi

# clear script as in progress for watchdog
clear_now_timestamp "${ETMCRASH_TS_FILE}"

exit 0
