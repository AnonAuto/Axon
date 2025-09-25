#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script contains common script elements used throughout the ETM
# script subsystems
#

export ASAN_OPTIONS="poison_heap=0:poison_array_cookie=0:start_deactivated=1"

. /etm/bin/etm-net-common.sh

# Log directory on SD card rootfs partition
LOG_DIR="/root/log"
# Log directory inside /var (this directory is a symlink on  TMPFS_LOG_DIR).
# Please note, that the same path is defined in etmd sources in main.cpp as
# ETMD_LOG_DIR. If you change it here, please also update it there,
# otherwise logs sync will not work.
VAR_LOG_DIR="/var/log"
# Log directory on TMPFS ramdisk partition
TMPFS_LOG_DIR="/var/volatile/log"
# Temporary directory (it's a symlink on TMPFS_ETM_TMP_DIR)
ETM_TMP_DIR="/tmp"
# Temporary directory on TMPFS ramdisk partition
TMPFS_ETM_TMP_DIR="/var/volatile/tmp"
# State directory (it's a symlink on TMPFS_STATE_DIR)
STATE_DIR="/var/state"
# State directory on TMPFS ramdisk partition
TMPFS_STATE_DIR="/var/volatile/state"
# Spool directory (it's a symlink on TMPFS_SPOOL_DIR)
SPOOL_DIR="/var/spool"
# Spool directory on TMPFS ramdisk partition
TMPFS_SPOOL_DIR="/var/volatile/spool"
# Proxy info directory
PROXY_DIR="/var/volatile/run/proxy"
# Setting CURL_HOME
export CURL_HOME="/var/volatile/run/curl"

# Root CA list for SSL operations.  Passed to CURL and also used in ETMD
SSL_CA_BUNDLE="/etc/ssl/ca-bundle.crt"

ETM_VERSION=$(cat /etm/bin/version)
ETM_BUILDINFO=$(cat /etm/bin/buildinfo)
ETMD=/etm/bin/etmd

# LED control GPIOs       #33/35 :     GPIO1_1, GPIO1_3 are used to control the bi-color LED.
#                                      GPIO1_1(HI) GPIO1_3(LO) to turn on Green LED
#                                      GPIO1_1(LO) GPIO1_3(HI) to turn on red LED
#                                      GPIO1_1(LO) GPIO1_3(LO) to turn off
#                                      GPIO1_1(HI) GPIO1_3(HI) to turn off
#
# USB power control GPIOs #32/34 :     GPIO1_0, GPIO1_2 are used to control USB power ICs
#                                      GPIO1_0(HI) to turn on USB_0 port
#                                      GPIO1_2(HI) to turn on USB_1 port
#                                      GPIO1_0(LO) to turn off USB_0 port
#                                      GPIO1_2(LO) to turn off USB_1 port
#
# GPIOs are exported via /sys/class/gpio/export

GPIO_USB0=32
GPIO_USB1=34
GPIO_LED0=33
GPIO_LED1=35
GPIO_PATH=/sys/class/gpio
GPIO_USB0_PATH=${GPIO_PATH}/gpio${GPIO_USB0}
GPIO_USB1_PATH=${GPIO_PATH}/gpio${GPIO_USB1}
GPIO_LED0_PATH=${GPIO_PATH}/gpio${GPIO_LED0}
GPIO_LED1_PATH=${GPIO_PATH}/gpio${GPIO_LED1}

MUSB_HDRC_DRIVER_CONTROL_PATH=/sys/bus/platform/drivers/musb-hdrc
USB0_MUSB_HDRC_INSTANCE=musb-hdrc.0
USB1_MUSB_HDRC_INSTANCE=musb-hdrc.1

# Log Files
#
# "archive" files are logs that failed to upload in the past - we retry until they succeed
# the "bak" file for etmd.log are logs saved from previous instances of etmd
# the debug files are local copies of what has been successfully uploaded for debugging
# the .0 file is from automatic syslog rotation
# the temp syslog copy is used to capture logging messages during the actual syslog upload
# attempt,
UPLOAD_LOG=${LOG_DIR}/etm.temp

SYSLOG_FILE=${LOG_DIR}/syslog
SYSLOG_TMPFS_FILE="${TMPFS_LOG_DIR}/syslog"
SYSLOG_TMPFS_ROT0="${TMPFS_LOG_DIR}/syslog.0"
# dash not dot in file name to avoid DOCK-1246
SYSLOG_EMERG=${LOG_DIR}/syslog-emerg
SYSLOG_DEBUG=${LOG_DIR}/syslog-debug

RESTART_DEBUG=${LOG_DIR}/restart.debug
REBOOT_DEBUG=${LOG_DIR}/reboot.debug
ENUMERATE_DEBUG=${LOG_DIR}/enumerate.debug

ETMLOG_FILE=${LOG_DIR}/etmd.log
ETMLOG_DEBUG=${LOG_DIR}/etmd.debug

LIGHTTPD_LOG_ACCESS="${LOG_DIR}/lighttpd.access.log"
LIGHTTPD_TMPFS_LOG_ACCESS="${TMPFS_LOG_DIR}/lighttpd.access.log"
LIGHTTPD_LOG_BREAKAGE="${LOG_DIR}/lighttpd.breakage.log"
LIGHTTPD_TMPFS_LOG_BREAKAGE="${TMPFS_LOG_DIR}/lighttpd.breakage.log"
LIGHTTPD_LOG_ERROR="${LOG_DIR}/lighttpd.error.log"
LIGHTTPD_TMPFS_LOG_ERROR="${TMPFS_LOG_DIR}/lighttpd.error.log"

# Configuration for logs sync from tmpfs ramdisk to SD card
#
# This file is created by etm-watchdog.sh script and contains timestamp (in seconds since the Epoch)
# of the last synchronization; saving timestamp in the external file on the tmpfs partition allows
# to prevent logs synchronization every time when etm-watchdog.sh restarts and allows to keep
# constant LOGS_SYNC_INTERVAL.
# Please note that timestamp in LOGS_SYNC_TS_FILE gets updated by etm-watchdog.sh once
# sync-etm-log.sh is completed
LOGS_SYNC_TS_FILE="/var/run/logs-sync-timestamp"
ETMWATCHDOG_TS_FILE="/var/run/etmwatchdog-timestamp"
ETMSTAT_TS_FILE="/var/run/etmstat-timestamp"
ETMCRASH_TS_FILE="/var/run/etmcrash-timestamp"

# logs sync interval in seconds
LOGS_SYNC_INTERVAL=300

# This temporary file is created (and removed) by sync-etm-log.sh.
# Once sync-etm-log.sh is started it creates this file and saves current yymmdd.HHMMSS timestamp there.
# When it does logs sync, it takes name of a log file on TMPFS partiton, appends this timestamp and saves
# this new file in a log dir on SD card.
# For example, timestamp = 140101.2102053 (Jan 01, 2014 09:02:53 PM), log filename is /var/volatile/log/syslog,
# so sync-etm-log.sh will create /root/log/syslog.140101.2102053 with all data from the original file.
# For etmd.log.* files it will take the all (sorted by their timestamp) and save everything to a single
# /var/volatile/etmd.log.140101.2102053 file. After synchronizing all logs, sync-etm-log.sh deletes this
# temporary file.
# Described mechanism allows etm-sync-log.sh run any time and don't care about other log-related scripts
# like etmcrash.sh or truncate-etm-log.sh.
LOGS_SYNC_OUT_FILENAME_TS_FILE="/var/run/logs-sync-out-filename-timestamp"

if [ -f /etm/bin/version.debug ]; then
    ETM_DEBUG_BUILD=1
else
    ETM_DEBUG_BUILD=
fi

# model changes need to be made in the following places also:
# /files/lua/register-ecom.lua
# status-app.h
# EVIDENCE.COM server-side
TASER_DEVICE_TYPE=taser_etm
TASER_DEVICE_MODEL=taser_etm_flex_2
# for historic reason we have a different model for crash logs
CRASH_LOG_MODEL=ETM_FLEX_2

# serial number that is used for development if the image isn't serialized
DEFAULT_SERIAL=X79000000

SN=${DEFAULT_SERIAL}
if [ -f /etc/etm-serial ]; then
    SN=$(cat /etc/etm-serial)
fi

# Directory where RSA private key and self-signed certificate for HTTPS are stored
HTTPS_SECRET_DIR="/etm/secret"

# source the UCI wrapper functions
# note the UCI wrappers all assume that
# the uci executable is at /sbin/uci
# we make the same assumption as a convenience.
. /etc/uci-functions.sh

# Check if nameserver is available and can resolve test domain name. This function is a wrapper for
# host DNS lookup utility (part of bind-utils package), it takes single parameter - IP address of
# the nameserver and returns 0 if it was able to resolve test domain name or 1 otherwise.
# Please note: if target nameserver is not responding, this function will be running few seconds more than
# defined in REQUEST_TIMEOUT.
check_nameserver() {
    # input parameter - IP address of a nameserver to check
    local NAME_SERVER="$1"
    # local constant - timeout in seconds,defines how long to wait for a reply
    local REQUEST_TIMEOUT=3
    # local constant - test domain name
    local TEST_SERVER_NAME="prod.evidence.com"

    config_load etm
    config_get AGENCY operation agency_domain

    if [[ ! -z "${AGENCY}" ]]; then
        TEST_SERVER_NAME="${AGENCY}"
    fi

    check_name_server_helper "${NAME_SERVER}" "${TEST_SERVER_NAME}" 0
}

# This is a recursive function calling itself to resolve address of an alias. It will call itself a maximum
# of 10 times. The 3rd parameter provides the current level. The caller can pass in any value for "RECURSE_LEVEL"
# and the this function will call itself 10-RECURSE_LEVEL number of times.
check_name_server_helper(){
    local NAME_SERVER="$1"
    local TEST_SERVER_NAME="$2"
    local RECURSE_LEVEL="$3"

    if [[ -z "${RECURSE_LEVEL}" ]]; then
        RECURSE_LEVEL=0 #default
    fi
    # if this function is called too many times recursively then exit
    if [[ "${RECURSE_LEVEL}" -gt 10 ]]; then
        return 1
    fi

    # return code, 0 = success, 1 = failure
    local RC=1

    if [[ ! -z "${NAME_SERVER}" ]] ; then
        # call host DNS lookup utility
        # A. on success host returns 0 and outputs:
        #
        #     Using domain server:
        #     Name: 8.8.8.8
        #     Address: 8.8.8.8#53
        #     Aliases:
        #
        #     prod.evidence.com has address 107.21.25.241
        #
        # B. test server is an alias and the alias address is resolved:
        #
        #     Using domain server:
        #     Name: 10.6.1.112
        #     Address: 10.6.1.112#53
        #     Aliases:
        #
        #     mail.google.com is an alias for googlemail.l.google.com.
        #     googlemail.l.google.com has address 216.58.216.133
        #     googlemail.l.google.com has IPv6 address 2607:f8b0:400a:800::2005
        #
        # C. on failure, when test domain name is invalid but DNS is actually active and responding,
        #   host returns 1 and outputs:
        #
        #     Using domain server:
        #     Name: 8.8.8.8
        #     Address: 8.8.8.8#53
        #     Aliases:
        #
        #     Host evidencefgdf.com not found: 3(NXDOMAIN)
        #
        # D. on failure, when DNS server is invalid, host returns 1 and outputs:
        #
        #     ;; connection timed out; no servers could be reached
        #
        # case A and B are considered as success; in case C, name server is responding but it actually can't resolve
        # our test domain name so it's a failure; case D is a failure.
        local HOST_OUT
        HOST_OUT="$(host -W "${REQUEST_TIMEOUT}" "${TEST_SERVER_NAME}" "${NAME_SERVER}")"
        local HOST_RC=$?
        if [[ ${HOST_RC} -eq 0 ]] ; then
            # first check if the actual server name returned an address or not
            if [[ -n "$(echo "${HOST_OUT}" | grep "${TEST_SERVER_NAME} has address")" ]]; then
                RC=0
            else # check if an alias exists for the name, if so try to resolve the alias
                local ALIAS
                ALIAS="$(echo "${HOST_OUT}" | grep "${TEST_SERVER_NAME} is an alias for" | awk '{print $NF}')"
                # The awk printed the last field which contains the period symbol. Ex: "googlemail.l.google.com."
                # The '.' needs to be removed from the end if it exists. Using sed tool: find the '.' character
                # (needs to be escaped with backslash), at the end of the line ('$'), and replace with nothing
                ALIAS="$(echo "${ALIAS}" | sed 's/\.$//')"
                RC=$(check_name_server_helper "${NAME_SERVER}" "${ALIAS}" $((RECURSE_LEVEL + 1)))
            fi
        fi
    fi

    return ${RC}
}

# Read current DNS configuration and test if nameservers can resolve domain names. Up to 2 nameservers supported.
# If current configuration contains more than 2 nameservers then this function takes only first 2 and ignores the rest.
# This function takes single parameter - log identifier (see description below).
# This function returns 0 (success) if DNS1 OR DNS2 are able to resolve domain names. In all other cases
# (considered as error) this function returns 1.
check_dns_cfg() {
    # $1 = log identifier, allows to find in the logs which script called this function, for example
    #      /etm/bin/set-rtc.sh uses "set-rtc".
    local readonly LOG_ID="$1"
    local readonly RESOLVCONF="/etc/resolv.conf"

    # BWE-2813: There is a case where customer's DNS servers (sent by DHCP server) does not resolve external IPs,
    # but the proxy server can. The consequence is `curl --proxy <proxy-server> https://time.evidence.com/ping`
    # works (because proxy-server is the one that resolve doamain `time.evidence.com`) but `host time.evidence.com` fails.
    # The solution is to let user disable this dns check if `etm.proxy.disable_dns_check` flag is set to true.
    config_load etm
    config_get_bool DISABLE_DNS_CHECK proxy disable_dns_check 0
    if [ "${DISABLE_DNS_CHECK}" = "1" ]; then
        log_info_msg "${LOG_ID}" "Event=IgnoreDnsCheck"
        return 0
    fi

    # read current DNS configuration and save it in a variable; implemented this way because there is a chance
    # that DNS configuration can change while check_dns_cfg will be reading RESOLVCONF line by line
    local readonly DNS_CFG="$(cat ${RESOLVCONF} 2>/dev/null)"
    if [[ $? -ne 0 ]] ; then
        log_err_msg "${LOG_ID}" "Unable to read ${RESOLVCONF}"
        return 1
    elif [[ -z "${DNS_CFG}" ]] ; then
        log_err_msg "${LOG_ID}" "DNS configuration is empty"
        return 1
    fi
    # filter out all nameserver records, extract IP addresses and save them to NAMESERVERS
    # save first two IP addresses as DNS1_IP and DNS2_IP
    local LINE=""
    local DNS1_IP=""
    local DNS2_IP=""
    local I=1
    # there are several ways to go line by line in a variable with multiple lines of text;
    # ash does not support:
    #     while read -r LINE ; do ... done <<< ${DNS_CFG}
    # and reports an error related with input redirect;
    # this one:
    #     print %s ${DNS_CFG} | while read -r LINE ; do ... done
    # results in empty  DNS*_IP variables even if the script was able to parse DNS IP addresses and save
    # them to DNS*_IP variables in the loop, the issue might be related with pipe handling;
    # so the following way with changing IFS was selected, so please do not replace it with anything
    # else if not 100% sure;
    # in order to read data line by line from ${DNS_CFG} we need to set internal field separator with newline,
    # otherwise it will split data by spaces; so save IFS before making any changes;
    local OIFS=${IFS}
    IFS='
'
    for LINE in ${DNS_CFG}; do
        local NAMESERVER_IP="$(echo "${LINE}" | grep nameserver | awk '{ print $2; }')"
        if [[ ! -z "${NAMESERVER_IP}" ]] ; then
            eval DNS${I}_IP="${NAMESERVER_IP}"
            log_verbose "${LOG_ID}" "Found DNS${I}=${NAMESERVER_IP} in ${RESOLVCONF}"
            I=$((I + 1))
            if [[ ${I} -gt 2 ]] ; then
                break
            fi
        fi
    done
    # restore IFS
    IFS=${OIFS}
    # test DNS1_IP and DNS2_IP nameservers
    local DNS1_OK=0
    local DNS2_OK=0
    if check_nameserver "${DNS1_IP}" ; then
        log_verbose "${LOG_ID}" "DNS1=${DNS1_IP} is OK"
        DNS1_OK=1
    else
        log_err_msg "${LOG_ID}" "DNS1=${DNS1_IP} is failed a test"
    fi
    if [ ! -z ${DNS2_IP} ]; then
        if check_nameserver "${DNS2_IP}" ; then
            log_verbose "${LOG_ID}" "DNS2=${DNS2_IP} is OK"
            DNS2_OK=1
        else
            log_err_msg "${LOG_ID}" "DNS2=${DNS2_IP} is failed a test"
        fi
    # else DNS2 is optional - eat silently
    fi

    # handle results
    if [[ ${DNS1_OK} -ne 1 ]] && [[ ${DNS2_OK} -ne 1 ]] ; then
        log_err_msg "${LOG_ID}" "DNS configuration is broken"
        return 1
    fi

    log_verbose "${LOG_ID}" "DNS configuration is OK"
    return 0
}

# Alerts through here trigger a direct, real-time notice to e.com
# assuming there appears to be a network connection.
send_critical_alert() {
    # $1 = name of logging utility
    # $2 = alert code (no spaces)
    local UTILITY="$1"
    local ALERT_CODE="$2"
    local AGENCY=

    config_load etm
    config_get AGENCY operation agency_domain

    if [ -z "$AGENCY"  ]; then
        AGENCY=edca.evidence.com
    fi

    local SCHEME="https"

    if [[ ${ETM_DEBUG_BUILD} ]] && [[ "${AGENCY}" == "dev1.evidence.com" ]]; then
        SCHEME="http";
    fi

    local URL="${SCHEME}://${AGENCY}/1/device/stats/send/?device_model=${TASER_DEVICE_MODEL}&device_type=${TASER_DEVICE_TYPE}&device_sn=${SN}"

    if ! check_dns_cfg "send_critical_alert" ; then
        log_err_msg "send_critical_alert" "DNS configuration check failed, unable to send alert."
    else
        # First, call the fatal alert API on e.com before doing anything else.

        local TIMEOUT=20
        # pid is the process being watched for timeout
        local $pid
        # watcher is the pid of the timeout process so it can
        # be shutdown if the watched process exits more quickly
        local $watcher
        (
            ( curl --cacert ${SSL_CA_BUNDLE} -X PUT -d "${ALERT_CODE}" "${URL}" ) & pid=$!
            ( sleep $TIMEOUT && ( kill -HUP $pid && log_err_msg ${SERVICE_NAME} "Timeout sending critical alert" ) ) 2>/dev/null & watcher=$!
            wait $pid 2>/dev/null && pkill -HUP -P $watcher
        )

        # TODO_IDEA figure out how to smuggle result from subshell CURL to log failure.  However, since
        # we are in a critical situation, there's no guarantee of recording or recovering from failure
        # so choosing to ignore for now.
    fi

    # log it
    log_err_msg "$1" "$2"
}

# global variable used to display elapsed time.
# Can be reset to use multiple times in caller if
# desired
START_SECONDS=$(date +"%s")
reset_start_time() {
    START_SECONDS=$(date +"%s")
}

# time functions
log_elapsed_time_from() {
    # $1 = task
    # $2 = start time
    local startSeconds=$2
    local endSeconds=$(date +"%s")
    local sec=$(( $endSeconds - $startSeconds ))
    local hours=$(( $sec / 3600 ))
    sec=$(( $sec % 3600 ))
    local min=$(( $sec / 60 ))
    sec=$(( $sec % 60 ))

    log_info_msg "$1" "Elapsed Time (h:m:s): $(printf %02d ${hours}):$(printf %02d ${min}):$(printf %02d ${sec})"
}

log_elapsed_time() {
    # $1 = name of measured task
    log_elapsed_time_from "$1" ${START_SECONDS}
}


# Force a required directory to exist as a directory.
# Please note that this function outputs error messages to stderr.
# WARNING: this function will delete any conflicting files or links.
force_create_dir() {
    local DIR_PATH="$1"
    local DIR_MODE="$2"

    if [[ -z "${DIR_PATH}" ]]; then
        echo "ERROR: force_create_dir() - required argument missing" >&2
        return
    fi

    if [[ -z "${DIR_MODE}" ]]; then
        DIR_MODE="0755"
    fi

    if [[ ! -d "${DIR_PATH}" ]]; then
        # force remove for specified path, before creating a directory;
        # it's required for the case when there is some node at specified
        # path, but it's definitely not a directory
        if ! rm -rf "${DIR_PATH}" ; then
            echo "ERROR: force_create_dir() - unable to remove ${DIR_PATH}" >&2
            return
        fi

        if ! mkdir -m "${DIR_MODE}" -p "${DIR_PATH}" ; then
            echo "ERROR: force_create_dir() - unable to create ${DIR_PATH} with mode ${DIR_MODE}" >&2
        fi
    fi
}

# Force a required symlink to exist as a symlink.
# Please note that this function outputs error messages to stderr.
# WARNING: this function will delete and conflicting files or directories.
#
# This function allows to avoid strange busybox's behaviour - when the symlink exists (and already
# points to a target directory) 'ln -sf' will not delete it but will follow it and will create a new
# symlink within a target directory pointing to this directory, which is crazy and wrong.
# specifying -n option (which is 'Don't dereference symlinks - treat like normal file') for ln doesn't
# solve this issue.
force_create_symlink() {
    local TARGET_PATH="$1"
    local SYMLINK_PATH="$2"

    if [[ -z "${TARGET_PATH}" ]] || [[ -z "${SYMLINK_PATH}" ]]; then
        echo "ERROR: force_create_symlink() - required arguments missing" >&2
        return
    fi

    if ! rm -rf "${SYMLINK_PATH}" ; then
        echo "ERROR: force_create_symlink() - unable to remove ${SYMLINK_PATH}" >&2
        return
    fi

    if ! ln -sf "${TARGET_PATH}" "${SYMLINK_PATH}" ; then
        echo "ERROR: force_create_symlink() - unable to create ${SYMLINK_PATH} symlink for ${TARGET_PATH}" >&2
    fi
}

# Wait for given PID to exit. Please note that if timeout value is not specified this function will wait while
# the target process is running.
pwait() {
    # ${1} - PID to wait
    # ${2} - wating timeout, in seconds; this paramenter is optional
    #
    # This function returns:
    # 0    wating completed
    # 1    timeout is occured

    local PID="$1"
    local WAIT_TIMEOUT="$2"

    if [[ ! -z "${WAIT_TIMEOUT}" ]] && [[ "${WAIT_TIMEOUT}" -le 0 ]]; then
        # wating timeout is not a positive integer, ignore it
        WAIT_TIMEOUT=
    fi

    local START_TS="$(date +%s 2>/dev/null)"

    while [[ ! -z "${PID}" ]] && [[ -d "/proc/${PID}" ]] && [[ -z "$(grep zombie "/proc/${PID}/status")" ]]; do
       sleep 1

        # handle timeout
        if [[ ! -z "${WAIT_TIMEOUT}" ]]; then
            local CURRENT_TS="$(date +%s 2>/dev/null)"
            local DELTA_TS=$((${CURRENT_TS} - ${START_TS}))

            if [[ "${DELTA_TS}" -ge "${WAIT_TIMEOUT}" ]]; then
                # a timeout has occured
                return 1
            fi
        fi
    done

    return 0
}

# Kill a tree of processes (i.e. the parent, its children, grandchildren... etc).
# This solution was originally discovered at: http://stackoverflow.com/a/3211182
# It's better than killing process tree by Process Group ID because sometimes various processes might be in a same group, but they
# might not be related as parent-child.
# If a child calls this on its parent/grandparent then that child will not be killed, includings its own children.
killtree() {
    local PID="$1"
    local SIGNAL="$2"

    if [[ -z "${SIGNAL}" ]] ; then
        SIGNAL="TERM"
    elif [[ "${SIGNAL}" != "TERM" ]]; then
        SIGNAL="KILL"
    fi

    if [[ "${PID}" != "$$" ]]; then # don't try to kill the original caller/self (the current process)
        kill -stop "${PID}" # needed to stop quickly forking parent from producing children between child killing and parent killing
        for CHILD in $(ps -o pid --no-headers --ppid "${PID}"); do
            killtree "${CHILD}" "${SIGNAL}"
        done
        kill -"${SIGNAL}" "${PID}"
        kill -cont "${PID}" # since process was stopped, it does not terminate if $SIGNAL is SIGTERM, so we need send SIGCONT
        pwait "${PID}"      # and wait until it terminates
    fi
}

# manage timestamp/progress files for watchdog timer
write_now_timestamp() {
    local SERVICE=$1
    local TSFILE=$2
    STAT_TS="$(date +%s 2>/dev/null)"
    echo "${STAT_TS}" > "${TSFILE}"
    if [[ "$?" -ne 0 ]]; then
        log_err_msg "${SERVICE}" "Unable to save timestamp to ${TSFILE}"
    fi
}

clear_now_timestamp() {
    local TSFILE=$1
    rm ${TSFILE}
}

shutdown_etm() {
    /etc/init.d/etm-wd.sh stop
    /etc/init.d/etm.sh stop
}

start_etm() {
    /etc/init.d/etm-wd.sh start
    /etc/init.d/etm.sh start
}

shutdown_lighttpd() {
    /etc/init.d/lighttpd stop
}

start_lighttpd() {
    /etc/init.d/lighttpd start
}

# common function to make /tmp/status.config and filter out sensitive information;
# used by etmcrash.sh and etmstat.sh
make_tmp_status_config() {
    # filter out the secret_key and replace real access_key with all 0s,
    # so ecom-status can check that this option is present, but no sensitive
    # information is exposed
    /sbin/uci -P ${STATE_DIR} export |\
        /bin/grep -v -e "secret_key" |\
        /bin/sed -e "s/option 'access_key' '.*/option 'access_key' '00000000000000000000000000000000'/" > /tmp/status.config
}

# Remove `uci show` escape characters. Example: `'First '\'' Name'` -> `First ' Name`
# See https://git.openwrt.org/?p=project/uci.git;a=blob;f=cli.c;hb=52bbc99f69ea6f67b6fe264f424dac91bde5016c#l200
remove_uci_show_escape() {
    local STR="${1}"
    # length(string) >= 2 && string[first] = ' && string[last] = '
    if [ "${#STR}" -ge 2 ] && [ "${STR:0:1}" = "'" ] && [ "${STR:0-1}" = "'" ]; then
        # Get string without first & last single quotes, then replace all `'\''` with `'`
        echo "${STR:1:-1}" | sed "s/'\\\''/'/g"
    else
        echo "${STR}"
    fi
}

# Replace `'` with `'\''` and put result in single quotes. Example: `First ' Name` -> `'First '\'' Name'`
# See https://git.openwrt.org/?p=project/uci.git;a=blob;f=cli.c;hb=52bbc99f69ea6f67b6fe264f424dac91bde5016c#l200
add_uci_show_escape() {
    local STR="${1}"
    echo "'$(echo "${STR}" | sed "s/'/'\\\''/g")'"
}

proxy_get_encryption_key() {
    local CID=$(cat /sys/block/mmcblk0/device/cid)
    local LAN_MAC=$(ifconfig -a | grep ${LAN_IFACE} | awk '{print $5}')
    echo "${CID}-${LAN_MAC}"
}

proxy_encrypt_data() {
    echo "${1}" | openssl aes-256-cbc -e -md md5 -a -k "${2}"
}

proxy_decrypt_data() {
    echo "${1}" | openssl aes-256-cbc -d -md md5 -a -k "${2}"
}

proxy_generate_runtime_config() {
    # remove existing runtime config files before generating new ones
    rm -f "${CURL_HOME}/.curlrc"
    rm -f "${PROXY_DIR}/proxy"

    # set up proxy config
    config_get_bool PROXY_ENABLE proxy enabled 0
    if [ "${PROXY_ENABLE}" = "1" ]; then
        logger -s -p daemon.info -t "etm-prep" "Setting up proxy info for curl"

        config_get PROXY_HOST proxy host
        config_get PROXY_PORT proxy port
        config_get PROXY_ENCRYPTED_USER proxy encrypted_un
        config_get PROXY_ENCRYPTED_PASS proxy encrypted_pw

        local PROXY_USER=""
        local PROXY_PASS=""
        if [ ! -z "${PROXY_ENCRYPTED_USER}" ] && [ ! -z "${PROXY_ENCRYPTED_PASS}" ]; then
            local KEY=$(proxy_get_encryption_key)
            PROXY_USER=$(proxy_decrypt_data "${PROXY_ENCRYPTED_USER}" "${KEY}")
            PROXY_PASS=$(proxy_decrypt_data "${PROXY_ENCRYPTED_PASS}" "${KEY}")
        fi

        # generate cURL config
        touch "${CURL_HOME}/.curlrc" && chmod 600 "${CURL_HOME}/.curlrc"
        echo "proxy = \"http://${PROXY_HOST}:${PROXY_PORT}\"" >> "${CURL_HOME}/.curlrc"
        if [ ! -z "${PROXY_USER}" ] && [ ! -z "${PROXY_PASS}" ]; then
            echo "proxy-user = ${PROXY_USER}:${PROXY_PASS}" >> "${CURL_HOME}/.curlrc"
        fi
        echo "proxy-anyauth" >> "${CURL_HOME}/.curlrc"

        # generate proxy info for other daemons
        touch "${PROXY_DIR}/proxy" && chmod 600 "${PROXY_DIR}/proxy"
        uci -c "${PROXY_DIR}" set proxy.proxy=proxy
        uci -c "${PROXY_DIR}" set proxy.proxy.host="${PROXY_HOST}"
        uci -c "${PROXY_DIR}" set proxy.proxy.port="${PROXY_PORT}"
        if [ ! -z "${PROXY_USER}" ] && [ ! -z "${PROXY_PASS}" ]; then
            uci -c "${PROXY_DIR}" set proxy.proxy.username="${PROXY_USER}"
            uci -c "${PROXY_DIR}" set proxy.proxy.password="${PROXY_PASS}"
        fi
        uci -c "${PROXY_DIR}" commit proxy
    fi
}

# LOGIN_CLIENT_ID: https://axon.quip.com/TddNAcxeVarw/Create-an-OAuth-App-in-Universal-Login#temp:s:temp:C:ATYcea63cbedaa8407f8848661a6;temp:C:ATY30aa5cdf6cff452e98b242bd6
LOGIN_CLIENT_ID="b5e7c9d6-6776-498d-adea-9aa77a72ee69"
LOGIN_CFG_DIR_PATH="/tmp"
LOGIN_CFG_FILE="login-info"
LOGIN_CFG_FILE_PATH="${LOGIN_CFG_DIR_PATH}/${LOGIN_CFG_FILE}"

censor_value() {
    config=$1
    value=$2

    case "$config" in
        "user_code" )
            echo "${value:0:4}***"
            ;;
        "device_code" | "code_verifier" | "code_challenge" | "access_token" | "verification_uri_complete" )
            echo "*"
            ;;
        *)
            echo "$value"
            ;;
    esac
}

save_login_config() {
        if ! [ -e ${LOGIN_CFG_FILE_PATH} ]; then
                echo "config login 'info'" > ${LOGIN_CFG_FILE_PATH}
                chmod 600 ${LOGIN_CFG_FILE_PATH}
        fi

        config=$1
        value=$2 
        log_value=$(censor_value "$config" "$value")

        /sbin/uci -c ${LOGIN_CFG_DIR_PATH} set "${LOGIN_CFG_FILE}.info.${config}"=${value} > /dev/null 2>&1
        error=$?
        if [ $error -ne 0 ]; then
                log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToSaveLoginConfig Config=${config} Value=${log_value} Error=${error}"
                return 1
        fi

        /sbin/uci -c ${LOGIN_CFG_DIR_PATH} commit ${LOGIN_CFG_FILE} > /dev/null 2>&1
        error=$?
        if [ $error -ne 0 ]; then
                log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToSaveLoginConfig Config=${config} Value=${log_value} Error=${error}"
                return 1
        fi

        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=SaveLoginConfig Config=${config} Value=${log_value}"
        return 0
}

load_login_config() {
        if ! [ -e ${LOGIN_CFG_FILE_PATH} ]; then {
            return 1
        }
        fi        

        config=$1

        value=$( /sbin/uci -c ${LOGIN_CFG_DIR_PATH} get "${LOGIN_CFG_FILE}.info.${config}" )
        error=$?
        if [ $error -ne 0 ]; then
                log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToLoadLoginConfig Config=${config} Error=${error}"
                return 1
        fi

        echo "$value"
        return 0
}

json_extract() {
    read -r json
    key=$1
    type=$2
    val=""

    case $type in
        "boolean")
            val=$(echo ${json} | sed -n 's/.*"'${key}'"\s*:\s*\([a-zA-Z]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
            ;;
        "number")
            val=$(echo ${json} | sed -n 's/.*"'${key}'"\s*:\s*\([0-9]*\).*/\1/p')
            ;;
        *)
            val=$(echo ${json} | sed -n 's/.*"'${key}'"\s*:\s*"\([^"]*\)".*/\1/p')
            ;;
    esac

    if [ -z "${val}" ]; then
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToParseJson Field=${key}"
        return 1
    fi
    
    echo "${val}"
    return 0
}

is_curl_error_ssl_related() {
    error_code=$1
    # ref: https://curl.se/libcurl/c/libcurl-errors.html
    # informative ref (though not so up-to-date): https://everything.curl.dev/usingcurl/returns
    case $error_code in
        "35" | "51" | "53" | "54" | "58" | "59" | "60" | "64" | "66" | "77" | "80" | "82" | "83" | "90" | "91" | "98")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
