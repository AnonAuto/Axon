#!/bin/sh 
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: set-rtc.sh [force]
#
# set time (if necessary)

# DEFAULT time - 
# We insert Jan 1, 2000 into the build as /etc/timestamp.
#
# If the system clock is not set when the machine boots, then the 
# system time and hardware clock will be set to this and the resulting time
# on the machine will satisfy the condition less than UNSET_TIME below.
#
# this was chosen to be clearly distinct from anything that might occur in 
# reality and testing as a flag that we need to set the time.

# load our common functions, including UCI file support
. /etm/bin/etm-common.sh

SERVICE_NAME="set-rtc"

# UNSET_TIME is the time to set to clear the date
# this is 00:00 on April 1, 2016
UNSET_TIME="2016.04.01-00:00:00"

# MIN_VALID_TIME is special timestamp used for date validation after
# calling ntpd/curl. Ideally it must be UNSET_TIME + execution time for
# ntpd/curl, but generally we can use any value which is smaller than value
# set but greater than UNSET_TIME + execution time.
# The system default time is Apr 1st 2016, so if the system has been up for less than a month
# and failed to get time in the past, we will retry, but in practice this should be a decent 
# way to avoid unnecessary NTP traffic.
# this is 01:00 on Apr 1, 2016
MIN_VALID_TIME="2016.04.01-01:00:00"

# following timestamps are used for date sanity check after calling ntpd/htpdate; date/time must
# be in this range
MAX_VALID_TIME="2030.01.01-00:00:00"

# FORCE_MODE = 1 means reset time regardless of current time.
FORCE_MODE=0

# date command + output format options
DATE_CMD="/bin/date +%Y.%m.%d-%H:%M:%S"


##
# call this function to write a successful time update status to the configuration files and exit
#
completeUpdate() {
    local RESULT=${1:-NA}
    # save ntpcheck state
    uci_set_state "etm" "status" "ntpcheck" "${RESULT}"

    # save the result into the hardware clock also
    # may be temporarily disabled for testing
    /sbin/hwclock -w 

    log_info_msg "${SERVICE_NAME}" "Event=ClockReset ForceMode=${FORCE_MODE} Result=${RESULT} NewDate=$(${DATE_CMD})"
    exit 0
}

##
# call this function to upon failure to save "time sync failed" state; does not do time reset anymore
# because it causes clock skew
#
failedUpdate() {
    local ERR_MSG="${1}"

    if [[ -z "${ERR_MSG}" ]]; then
        ERR_MSG="Event=ClockResetFailedAllAttempts ForceMode=${FORCE_MODE}"
    fi

    # save ntpcheck failed state
    uci_set_state "etm" "status" "ntpcheck" "NA"
    log_err_msg "${SERVICE_NAME}" "${ERR_MSG}"
    exit 1
}

##
# helper function, called by timeFromHtp() and timeFromNtp() to validate the date after getting it from the server;
# parameter: either empty (uses current date), or time to check (in epoch seconds)
# returns 0 if the date is OK and 1 on failure
# 
is_date_OK() {
    local CURRENT_TIME_EPOCH="$1"
    if [ -z "${CURRENT_TIME_EPOCH}" ]; then
        # get current timestamp in seconds since the Epoch
        CURRENT_TIME_EPOCH="$(/bin/date +%s)"
    fi
    # check if current timestamp is within defined scopes
    if [[ "${CURRENT_TIME_EPOCH}" -ge "${MIN_VALID_TIME_EPOCH}" ]] && [[ "${CURRENT_TIME_EPOCH}" -le "${MAX_VALID_TIME_EPOCH}" ]]; then
        # OK, current date passed sanity check
        return 0
    fi

    # FAILURE, current date failed sanity check
    return 1
}

##
# this function tries to set the time from a single NTP server specified as the first parameter
#
timeFromNtp() {
    local NTPSERVER="$1"
    local COMPLETE_STRING="NTP/${NTPSERVER}"
    local CONFFILE="/var/tmp/ntp.conf.${NTPSERVER}"
    local DRIFTFILE="/var/tmp/ntp.drift.${NTPSERVER}"
    cat >"${CONFFILE}" <<EOF
# because we are trying to recover from large offsets, 
# the drift file is temp and thrown away
driftfile ${DRIFTFILE}
# ignore all interfaces except WAN
interface ignore wildcard
interface listen ${WAN_IFACE}
# iburst - send a burst of cpackages when server is not available
# this is recomended option
server ${NTPSERVER} iburst
# Defining a default security setting
restrict default
EOF

    log_info_msg "${SERVICE_NAME}" "Event=TimeNtpQueryStart NtpServer=${NTPSERVER}"

    # save current time in seconds since the Epoch
    local START_TIMESTAMP_EPOCH
    START_TIMESTAMP_EPOCH="$(/bin/date +%s)"

    # since ntpd is a daemon timeout command doesn't handle its execution
    # properly, it always returns 0 even in case of timeout event;
    # it still can be used for terminating ntpd, but we need to handle timeout
    # differently

    # timeout in seconds for ntpd
    local TIMEOUT=30

    # save the output from execution, catch real execution time value
    local OUTPUT
    OUTPUT="$( { /usr/bin/time /bin/timeout -t ${TIMEOUT} /usr/bin/ntpd -d -nqg -c "${CONFFILE}"; } 2>&1)"
    # obtain the execution time
    local EXEC_TIME_SEC=0
    # extract real execution time value from output, as a result EXEC_TIME will contain the following lines:
    #   MM
    #   SS
    #   DS
    # where MM - minutes, SS - seconds and DS - tenths of second
    local EXEC_TIME_LINES
    EXEC_TIME_LINES=$(echo "${OUTPUT}" | /bin/grep real | /bin/egrep -o '[0-9]+')
    if [[ ! -z "${EXEC_TIME_LINES}" ]]; then
        # not using double quotes, so echo will print EXEC_TIME_LINES as a single line of numbers divided with spaces
        local EXEC_TIME_MM
        EXEC_TIME_MM=$(echo ${EXEC_TIME_LINES} | /usr/bin/awk '{print $1}')
        local EXEC_TIME_SS
        EXEC_TIME_SS=$(echo ${EXEC_TIME_LINES} | /usr/bin/awk '{print $2}')
        EXEC_TIME_SEC=$((EXEC_TIME_MM * 60 + EXEC_TIME_SS))
    fi

    # toss temp files
    rm -f "${DRIFTFILE}" "${CONFFILE}"

    # ensure that date and time is within reasonable limits 
    if ! is_date_OK ; then
        # this can happen only if date/time was not OK before calling NTPD or
        # if NTPD somehow screwed date/time (unlikely to happen), so we play safe
        /bin/date +%s @$(( START_TIMESTAMP_EPOCH + EXEC_TIME_SEC ))
        log_err_msg "${SERVICE_NAME}" "Event=TimeNtpQueryFail Reason=BadDate"
    else
        # date/time is OK, check NTPD's exit status
  
        # when ntpd successfully syncs with remote server, the output looks like:
        #   clock_update: at 7 sample 7 associd 29436
        #   step_systime: step 0.147388 residual 0.000000
        #   In ntp_set_tod
        #   ntp_set_tod: clock_settime: 0: Success
        #   ntp_set_tod: Final result: clock_settime: 0: Success
        #   29 Apr 02:18:49 ntpd[31349]: ntpd: time set +0.147388 s
        #
        # then if sync with the same source and time delta is tiny the output looks like:
        #   event at 7 74.123.29.4 903a 8a sys_peer
        #   clock_update: at 7 sample 7 associd 35224
        #   29 Apr 02:22:42 ntpd[561]: ntpd: time slew -0.005280 s
        #   ntpd: time slew -0.005280s
        #
        # these both cases considered as SUCCESS
        #
        # when ntpd can't sync it gets terminated with SIGTERM by timeout:
        #   29 Apr 02:48:25 ntpd[10710]: ntpd exiting on signal 15
        #
        local EXIT_TIME_SET
        EXIT_TIME_SET=$(echo "${OUTPUT}" | /bin/grep "ntpd: time set" | /usr/bin/tail -n 1 | /usr/bin/wc -l)
        local EXIT_TIME_SLEW
        EXIT_TIME_SLEW=$(echo "${OUTPUT}" | /bin/grep "ntpd: time slew" | /usr/bin/tail -n 1 | /usr/bin/wc -l)
        local EXIT_SIGTERM
        EXIT_SIGTERM=$(echo "${OUTPUT}" | /bin/grep "ntpd exiting on signal 15" | /usr/bin/tail -n 1 | /usr/bin/wc -l)

        if [[ ${EXIT_TIME_SET} -gt 0 ]]; then
            log_info_msg "${SERVICE_NAME}" "Event=NtpTimeSet Status=TimeSet Server=${NTPSERVER}"
            completeUpdate "${COMPLETE_STRING}"
        elif [[ ${EXIT_TIME_SLEW} -gt 0 ]]; then
            log_info_msg "${SERVICE_NAME}" "Event=NtpTimeSet Status=TimeSlew Server=${NTPSERVER}"
            completeUpdate "${COMPLETE_STRING}"
        elif [[ ${EXIT_SIGTERM} -gt 0 ]] || [[ ${EXEC_TIME_SEC} -ge ${TIMEOUT} ]]; then
            log_err_msg "${SERVICE_NAME}" "Event=NtpFail Reason=Timeout Server=${NTPSERVER}"
        else
            # should never happen
            log_err_msg "${SERVICE_NAME}" "Event=NtpFail Reason=UnrecognizedOutput Output='${OUTPUT}'"
        fi
    fi
}

# convert a HTTP Header month name to number
MonthNum() {
    local MON_STR="$1"
    if [[ "$MON_STR" = "Jan" ]]; then
        echo "01"
    elif [[ "$MON_STR" = "Feb" ]]; then
        echo "02"
    elif [[ "$MON_STR" = "Mar" ]]; then
        echo "03"
    elif [[ "$MON_STR" = "Apr" ]]; then
        echo "04"
    elif [[ "$MON_STR" = "May" ]]; then
        echo "05"
    elif [[ "$MON_STR" = "Jun" ]]; then
        echo "06"
    elif [[ "$MON_STR" = "Jul" ]]; then
        echo "07"
    elif [[ "$MON_STR" = "Aug" ]]; then
        echo "08"
    elif [[ "$MON_STR" = "Sep" ]]; then
        echo "09"
    elif [[ "$MON_STR" = "Oct" ]]; then
        echo "10"
    elif [[ "$MON_STR" = "Nov" ]]; then
        echo "11"
    elif [[ "$MON_STR" = "Dec" ]]; then
        echo "12"
    fi
}

##
# this function tries to set the time from a single HTTP server specified as the first parameter
# and will timeout after 30 seconds
#
timeFromHtp() {
    local HTPSERVER="$1"
    local URL="http://${HTPSERVER}/ping"
    local COMPLETE_STRING="HTTP/${HTPSERVER}"
    
    if [[ ${HTTPS_TIME} -eq 1 ]]; then
        URL="https://${HTPSERVER}/ping"
        COMPLETE_STRING="HTTPS/${HTPSERVER}"
    fi

    log_info_msg "${SERVICE_NAME}" "Event=TimeHtpQueryStart URL=${URL}"
    
    # BWE-2668: What we want here is having Date from e.com. In case we use proxy,
    # we need to make sure that we don't accidentally use Date header returned by
    # the proxy server.
    #
    # The strategy here is to only use Date header when the received HTTP status
    # code from e.com is non-error (not 4xx and 5xx). That's why --fail is here.
    #
    # In case of proxy, since we use --proxy-anyauth, the output may have 2 Date
    # headers, one from request to proxy server, another is from request to e.com,
    # and we only need the last one.
    local CURL_OUTPUT_FILE=/tmp/set-rtc-curl.output
    /usr/bin/curl --fail -sI --max-time 30 --cacert "${SSL_CA_BUNDLE}" "${URL}" > "${CURL_OUTPUT_FILE}"
    local STATUS=$?
    if [[ ${STATUS} -eq 0 ]]; then
        local NEW_DATE="$(/bin/cat "${CURL_OUTPUT_FILE}" | /bin/grep "Date:" | /usr/bin/tail -1 | /usr/bin/cut -c12-32)"
        rm -f "${CURL_OUTPUT_FILE}"
        if [[ ! -z "${NEW_DATE}" ]]; then
            # example
            #          1
            #01234567890123456789
            #11 Nov 2015 18:01:02
            #
            # needs to be converted into format acceptable by date:
            # 2015.11.11-18:01:02
            local NEW_DATE_CONVERTED
            NEW_DATE_CONVERTED="${NEW_DATE:7:4}.$(MonthNum "${NEW_DATE:3:3}").${NEW_DATE:0:2}-${NEW_DATE:12:8}"
            local NEW_DATE_EPOCH
            NEW_DATE_EPOCH="$(/bin/date -d "${NEW_DATE_CONVERTED}" +%s)"
            if is_date_OK "${NEW_DATE_EPOCH}"; then
                # set new date/time
                /bin/date "${NEW_DATE_CONVERTED}"
                completeUpdate "${COMPLETE_STRING}"
            else
                log_err_msg "${SERVICE_NAME}" "Event=TimeHtpQueryFailed Reason=BadNewDate NewDate=${NEW_DATE} NewDateConverted=${NEW_DATE_CONVERTED} NewDateEpoch=${NEW_DATE_EPOCH}"
            fi
        else
            log_err_msg "${SERVICE_NAME}" "Event=TimeHtpQueryFailed Reason=EmptyNewDate URL=${URL}"
        fi
    else
        log_err_msg "${SERVICE_NAME}" "Event=TimeHtpQueryFailed Reason=CurlFailed Code=${STATUS} URL=${URL}"
    fi
}

##
#    MAIN
#

# get initial date/time stamp
INITIAL_DATE_TIME="$(${DATE_CMD})"
# get initial date/time stamp in seconds since the Epoch
INITIAL_DATE_TIME_EPOCH="$(/bin/date -d "${INITIAL_DATE_TIME}" +%s)"
# convert value of UNSET_TIME to seconds since the Epoch
readonly UNSET_TIME_EPOCH="$(/bin/date -d "${UNSET_TIME}" +%s)"
# convert value of MIN/MAX_VALID_TIME to seconds since the Epoch
readonly MAX_VALID_TIME_EPOCH="$(/bin/date -d "${MAX_VALID_TIME}" +%s)"
readonly MIN_VALID_TIME_EPOCH="$(/bin/date -d "${MIN_VALID_TIME}" +%s)"

# sanity check of the current date and time; this check is different than is_date_OK does,
# here UNSET_TIME is used as a threshold for minimum valid time
if [[ ${INITIAL_DATE_TIME_EPOCH} -lt ${UNSET_TIME_EPOCH} ]] || [[ ${INITIAL_DATE_TIME_EPOCH} -gt ${MAX_VALID_TIME_EPOCH} ]]; then
    # current date and time did not pass sanity check; set date and time to UNSET_TIME,
    log_info_msg "${SERVICE_NAME}" "Event=InitialTimeInvalid Time=${INITIAL_DATE_TIME}"
    /bin/date "${UNSET_TIME}" > /dev/null
    # time synchronization will be forced by the code below;
    # UNSET_TIME is less than MIN_VALID_TIME so is_date_OK will fail
    # and FORCE_MODE will be set to 1
fi

# FORCE mode can be enabled by a command line option or if the NTP check status is "NA"
if [[ "$1" == "force" ]]; then
    FORCE_MODE=1
else
    # running without "force", checking current NTP status
    NTP_STATUS="$(uci_get_state etm status ntpcheck)"
    # if current NTP_STATUS is not set or "NA" or current date fails sanity check then
    # force time synchronization
    if [[ -z "${NTP_STATUS}" ]] || [[ "$NTP_STATUS" == "NA" ]] || ! is_date_OK ; then
        # NTP sync is not OK, turning on the force mode
        log_info_msg "${SERVICE_NAME}" "Event=TimeStatusNotOk Note=SettingForceMode"
        FORCE_MODE=1
    fi
fi

if [[ ${FORCE_MODE} -eq 1 ]]; then
    log_info_msg "${SERVICE_NAME}" "Event=ClockSyncInForcedMode"
else
    # exit if we have something apparently valid and this is just a periodic check and not a force
    log_info_msg "${SERVICE_NAME}" "Event=ClockSyncSkipped"
    exit 0
fi

# check WAN IP address
WAN_IP="$(/sbin/ifconfig "${WAN_IFACE}" | /bin/grep inet | /usr/bin/awk '{print $2}' | /bin/sed  -e "s/addr://")"
if [[ -z "${WAN_IP}" ]]; then
    failedUpdate "Event=UnableClockSync Reason=NoWanIpAddress"
fi

# check DNS configuration
if ! check_dns_cfg "set-rtc" ; then
    failedUpdate "Event=UnableClockSync Reason=DNSFailed"
fi

#
# NOTE: Fall through indicates the previous attempt failed or timed out because 
#       we exit upon success via a call to completeUpdate
#

config_load etm

# AGENCY & UNSET MODE
config_get AGENCY operation agency_domain
if [[ -z "${AGENCY}" ]]; then
    AGENCY="time.evidence.com"
fi

# try via NTP to an agency-specific NTP server.
# prefer NTP over HTTP/S if agency specifically configured NTP,
# otherwise NTP is skipped altogether
config_get AGENCY_NTP etm ntp_domain
if [[ ! -z "${AGENCY_NTP}" ]]; then 
    timeFromNtp "${AGENCY_NTP}"
fi

# try via https://${AGENCY}/ping first
HTTPS_TIME=1
timeFromHtp "${AGENCY}"

# get 'require_https_time' option from the config file
config_get HTTPS_TIME etm require_https_time
if [[ -z "${HTTPS_TIME}" ]]; then
    # unlike bash busybox/ash does not 'turn' empty variable into 0 for numeric comparisons;
    # therefore if there is no 'require_https_time' option defined then config_get will unset
    # HTTPS_TIME, so we need to re-initialize it with 0
    HTTPS_TIME=0
fi

if [[ ${HTTPS_TIME} -eq 0 ]]; then
    # the option is not set, so try via http://${AGENCY}/ping
    timeFromHtp "${AGENCY}"
fi

# If we failed this far, give up.
failedUpdate

