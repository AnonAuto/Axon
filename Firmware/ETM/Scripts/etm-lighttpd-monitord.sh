#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013-2022 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

. /etm/bin/etm-common.sh

readonly SCRIPT_NAME="etm-lighttpd-monitord.sh"

# Check if the script is already running
RUN_COUNT=$(pgrep -f etm-lighttpd-monitord.sh | wc -l)
if [ "${RUN_COUNT}" -gt 2 ]; then
    log_info_msg_no_echo "Event=LighttpdMonitordAlreadyRunning Action=exit"
    exit 2
fi

# Disable lighttpd login for 10 minutes if user failed to provide correct credentials 5 times in 1 minutes
readonly LOCKDOWN_DURATION=600
readonly MAX_ATTEMPTS=5
readonly MAX_ATTEMPT_DURATION=60

should_lockdown_lighttpd() {
    if [ $# -lt 2 ]; then
        false
        return
    fi

    # Consume the 1st element.
    LAST=$1
    SUM=0
    shift

    # Go through the rest
    while [ -n "$1" ]; do
        CURRENT=$1
        SUM=$(( SUM + CURRENT - LAST ))
        LAST=${CURRENT}
        shift
    done

    if [ ${SUM} -lt ${MAX_ATTEMPT_DURATION} ]; then
        # We should lock down.
        true
        return
    fi
    false
    return
}

# Keep track how many times login has failed. Only reset when a login succeeds.
LOGIN_FAILED_COUNT=0

LOGIN_FAILED_TIMES_SIZE=0
LOGIN_FAILED_TIMES=""

# Read lighttpd logs continuously
# Putting `awk` here reduces the amount of text the while loop processes. We use `awk` instead of `grep` here because
# when `grep` writes to a pipe it keeps the output buffered, which makes this script slow to react to lighttpd logs.
# lighttpd logs example:
#   '2022-09-06 08:49:52: (../../lighttpd-1.4.55/src/mod_auth.c.1177) digest: auth ok'
#   '2022-09-06 09:13:33: (../../lighttpd-1.4.55/src/mod_auth.c.1135) digest: auth failed for  admin : wrong password, IP: 10.10.1.10'
#   '2022-09-06 09:14:12: (../../lighttpd-1.4.55/src/mod_authn_file.c.313) could not find entry for user  root , IP: 10.10.1.10'
#len(2022-09-06 08:49:52: (../../lighttpd-1.4.55/src/) = 48
tail -n0 -F "${LIGHTTPD_TMPFS_LOG_ERROR}" | awk '/^.{48}(mod_auth|mod_authn_file)\.c\.[0-9]+\) (digest: auth ok|digest: auth failed for|could not find entry for user)/' | while read line; do
    # `grep -q "digest: auth ok"` can let 'mod_authn_file.c.313) could not find entry for user  digest: auth ok , IP: 192.168.1.187' pass through.
    if echo "${line}" | grep -qE '^.{48}mod_auth\.c\.[0-9]+\) digest: auth ok'; then
        # Login OK, reset failure count.
        LOGIN_FAILED_COUNT=0
        LOGIN_FAILED_TIMES_SIZE=0
        LOGIN_FAILED_TIMES=""
        continue
    fi

    if echo "${line}" | grep -qE '^.{48}(mod_auth|mod_authn_file)\.c\.[0-9]+\) (digest: auth failed for|could not find entry for user)'; then
        SRCIP=$(echo "${line}" | awk '/.*/{print $NF}')
        # Login failed, increase failure count and save current time.
        LOGIN_FAILED_COUNT=$(( LOGIN_FAILED_COUNT + 1 ))
        LOGIN_FAILED_TIMES_SIZE=$(( LOGIN_FAILED_TIMES_SIZE + 1 ))
        LOGIN_FAILED_TIMES="${LOGIN_FAILED_TIMES} $(date +%s)"
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=WebUIAuthAttempFailed Count=${LOGIN_FAILED_COUNT} IP=${SRCIP}"
    fi

    # Defensively remove old entries so we don't accidentally consume all memory.
    if [ ${LOGIN_FAILED_TIMES_SIZE} -gt ${MAX_ATTEMPTS} ]; then
        set -- ${LOGIN_FAILED_TIMES}
        while [ ${LOGIN_FAILED_TIMES_SIZE} -gt ${MAX_ATTEMPTS} ]; do
            shift
            LOGIN_FAILED_TIMES_SIZE=$(( LOGIN_FAILED_TIMES_SIZE - 1 ))
        done
        LOGIN_FAILED_TIMES="$@"
    fi

    # If login failure count exceeds limit, check times.
    if [ ${LOGIN_FAILED_TIMES_SIZE} -ge ${MAX_ATTEMPTS} ]; then
        if should_lockdown_lighttpd ${LOGIN_FAILED_TIMES}; then
            LOGIN_FAILED_TIMES_SIZE=0
            LOGIN_FAILED_TIMES=""

            log_info_msg_no_echo "${SCRIPT_NAME}" "Event=WebUIDisableLogin Duration=${LOCKDOWN_DURATION} Reason=TooManyFailedLoginAttempts"
            cat "/etc/lighttpd-reject-login.conf" > "${TMPFS_ETM_TMP_DIR}/lighttpd-additional-config.conf"
            /etc/init.d/lighttpd restart
            sleep ${LOCKDOWN_DURATION}

            log_info_msg_no_echo "${SCRIPT_NAME}" "Event=WebUIEnableLogin Reason=LockdownPeriodOver"
            echo "" > "${TMPFS_ETM_TMP_DIR}/lighttpd-additional-config.conf"
            /etc/init.d/lighttpd restart
        fi
    fi
done
