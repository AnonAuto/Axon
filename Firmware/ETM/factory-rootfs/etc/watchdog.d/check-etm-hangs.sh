#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# test script called by the watchdog daemon to see if any of our service scripts
# have hung.
#
# returns 0 on success, or
#         255 to force a reboot
# Note that changing watchdog version to 5.14 requires changing the error codes
# since it appears to use 201 for reboot signaling now

# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

TRIGGER_REBOOT=255
SCRIPT_NAME=check-etm-hangs.sh

save_syslog_and_reboot() {
    # save the syslog from RAM before we die
    /bin/cp "${SYSLOG_TMPFS_FILE}" "${SYSLOG_EMERG}"
    exit $TRIGGER_REBOOT
}

if [ "$1" == "repair" ]; then
    # no repairs, just reboot
    log_err_msg  ${SCRIPT_NAME} "Requested to perform unsupport repair operation, requesting watchdog reboot..."
    save_syslog_and_reboot
fi

# Limit to a single instance
# disable shellcheck recommendataion of using pgrep since busybox pgrep does not have count option
# shellcheck disable=SC2009
RUN_COUNT=$(/bin/ps -A | /bin/grep -c check-etm-hangs.sh)

# why 2?
# because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
# no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
# a second instance is wrong and should trigger a reboot also
if [ "$RUN_COUNT" -gt 2 ]; then
    log_info_msg ${SCRIPT_NAME} "${SCRIPT_NAME} already running, exiting..."
    save_syslog_and_reboot
fi

test_hang() {
    local SERVICE_NAME=$1
    local TIMESTAMP_FILE=$2
    local TIMEOUT=$3

    local NOW_TS
    local STAT_TS
    local CONVERTED_STAT
    NOW_TS="$(/bin/date +%s 2>/dev/null)"
    STAT_TS="$(/bin/cat "${TIMESTAMP_FILE}" 2>/dev/null)"
    CONVERTED_STAT="$(/bin/date -d@"${STAT_TS}" 2>/dev/null)"
    if [[ -n "${STAT_TS}" ]] && [[ -n "${CONVERTED_STAT}" ]]; then # check if there was anything to read
        local DELTA=$(( NOW_TS - STAT_TS ))
        if [[ ${DELTA} -ge ${TIMEOUT} ]]; then
            log_err_msg ${SCRIPT_NAME} "${SERVICE_NAME} is hung, requesting watchdog reboot..."
            save_syslog_and_reboot
        fi
    fi
}

#### MAIN ####

# check etm-watchdog, etmstat.sh & etmcrash.sh for hangs

test_hang "etm-watchdog.sh" "${ETMWATCHDOG_TS_FILE}" 600
test_hang "etmstat.sh" "${ETMSTAT_TS_FILE}" 600
test_hang "etmcrash.sh" "${ETMCRASH_TS_FILE}" 600

exit 0
