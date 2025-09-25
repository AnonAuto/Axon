#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script watches the ETM processes and tries to take
# corrective action when appropriate
#

. /etm/bin/etm-common.sh

PID_FILE=/var/run/etm.pid
STATE_FILE=/tmp/etm.state

REBOOT_FILE=/etm/reboot_out.log
UCI_FILE=/etm/killall_uci_out.log
WATCHDOG_FILE=/etm/killall_watchdog.log
SERVICE_NAME=etm-wd

# log one line to syslog with the priority given
syslog_line() {
    local PRIORITY=$1
    local MSG=$2
    logger -s -p $PRIORITY -t ${SERVICE_NAME} "$MSG"
}

dump_to_syslog() {
    local FUNCNAME=$1;
    local RESULT=$2
    local FILENAME=$3;

    syslog_line daemon.emerg "Event=output Func=${FUNCNAME} result=${RESULT}"
    local n=0
    cat $FILENAME | while read LINE; do
        n=$((n+1))
        syslog_line daemon.info "Line $n = $LINE"
    done
}

sdcard_syslog_line() {
    local PRIORITY="$1"
    local MSG="$2"
    local DATE_TIME="$(date +"%b %e %T" 2>/dev/null)"
    local HOSTNAME="$(cat /etc/hostname 2>/dev/null)"
    echo "${DATE_TIME} ${HOSTNAME} ${PRIORITY} ${SERVICE_NAME}: ${MSG}" >> "${SYSLOG_FILE}"
    sync
}

dump_to_sdcard_syslog() {
    local FUNCNAME="$1"
    local RESULT="$2"
    local FILENAME="$3"

    sdcard_syslog_line "daemon.emerg" "Event=output Func=${FUNCNAME} result=${RESULT}"
    local n=0
    cat "${FILENAME}" | while read LINE; do
        n=$((n+1))
        sdcard_syslog_line "daemon.info" "Line ${n} = ${LINE}"
    done
}

force_reboot() {
    local ALERT="$1"

    # trigger LED notification on SOM board:
    /etm/bin/led-ctrl red

    sdcard_syslog_line "daemon.emerg" "Event=Entering_force_reboot"

    send_critical_alert "etm-watchdog.sh" "${ALERT}"

    sdcard_syslog_line "daemon.emerg" "Event=force_reboot_sleep sleep=3."
    sleep 3

    sdcard_syslog_line "daemon.emerg" "Event=force_reboot_killall_uci"
    killall uci > $UCI_FILE
    dump_to_sdcard_syslog "killall uci" "$?" "${UCI_FILE}"

    sleep 7
    sdcard_syslog_line "daemon.emerg" "Event=force_reboot_killall_uci_9"
    killall -9 uci > $UCI_FILE
    dump_to_sdcard_syslog "killall -9 uci" "$?" "${UCI_FILE}"

    sdcard_syslog_line "daemon.emerg" "Event=force_reboot_reboot_wait_90"
    reboot  > "${REBOOT_FILE}"
    dump_to_sdcard_syslog "reboot" "$?" "${REBOOT_FILE}"

    sleep 90

    sdcard_syslog_line "daemon.emerg" "Event=force_reboot_hang_90_forcing_reboot"
    reboot -f
}

force_ssl_regen() {
    # trigger generation of new RSA private key and self-signed certificate for HTTPS
    rm -rf "${HTTPS_SECRET_DIR}"
    /etc/init.d/etm-gen-cert.sh
    /etc/init.d/lighttpd restart
}

handle_web_requests() {
    # [web UI] check if web UI requested a restart of the network or the whole system
    local WEBUI_REQ_FILE="$(/bin/ls -1 /tmp/webUI.req.*.* | /usr/bin/head -n 1)"
    if [[ -f "${WEBUI_REQ_FILE}" ]]; then
        # read the request command
        local CMD="$(/bin/cat ${WEBUI_REQ_FILE})"
        # remove the request file
        /bin/rm -f "${WEBUI_REQ_FILE}"
        if [[ ! -z "${CMD}" ]]; then
            syslog_line daemon.info "Event=WebUICommand Cmd=${CMD}"

            # sync logs to move all current logs from ramdisk to SD card
            sync_logs

            # try to upload the crash log before anything changes
            /etm/bin/etmcrash.sh > /dev/null 2>&1

            case $CMD in
            "system")
                force_reboot "ui-reboot"
                ;;
            "etm")
                send_critical_alert "etm-watchdog.sh" "ui-restart"
                /etc/init.d/etm.sh restart
                ;;
            "ssl-regen")
                force_ssl_regen
                ;;
            "network")
                /etm/bin/apply-staged-network-settings.sh
                /etm/bin/etmstat.sh -n
                ;;
            "lighttpd")
                /etc/init.d/lighttpd restart
                ;;
            "snmpd")
                /etc/init.d/snmpd restart
                ;;
            "fw-update")
                echo '/etm/bin/etm-update.sh now' | batch > /dev/null
                ;;
            "dvr-fw-update")
                echo '/etm/bin/cache-dvr-fw.sh' | batch > /dev/null
                ;;
            "reset-reg")
                echo '/etm/bin/reset-reg' | batch > /dev/null
                ;;
            esac
        fi
    fi
}

check_rootfs() {
    # [rootFS check] try to create temp file on SD card, reboot if you can't...
    local FILE=$(mktemp -p ${LOG_DIR})
    if [ $? == 0 ]; then
        rm $FILE
    else
        syslog_line daemon.emerg "Event=root_FS_went_read_only Action=Reboot"
        force_reboot "readonly-fs"
    fi
}

log_if_syslog_error() {
    local ERR_MSG="$1"
    local LOG_MSG="$2"
    grep -e "${ERR_MSG}" "${SYSLOG_TMPFS_FILE}" > /dev/null 2>&1
    if [ $? == "0" ]; then
        syslog_line daemon.info "Event=IgnoringError ErrCode=${LOG_MSG}"
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "$(date) $(cat /etc/etm-serial) Watchdog Reboot (Ignored) " >> ${REBOOT_DEBUG}
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "${LOG_MSG}" >> ${REBOOT_DEBUG}

        # sync logs to move all current logs from ramdisk to SD card so we don't hit the same ignored line multiple times
        sync_logs
    fi
}

# check syslog for USB enumeration failure and re-enumerate if found
re_enumerate_if_syslog_error() {
    local ERR_MSG="$1"
    local LOG_MSG="$2"
    grep -e "${ERR_MSG}" "${SYSLOG_TMPFS_FILE}" > /dev/null 2>&1
    if [ $? == "0" ]; then
        syslog_line daemon.info "Event=ReenumerateUSB"
        echo "=========================================" >> ${ENUMERATE_DEBUG}
        echo "$(date) $(cat /etc/etm-serial) Device Re-enumerate" >> ${ENUMERATE_DEBUG}
        echo "=========================================" >> ${ENUMERATE_DEBUG}
        # sync logs to move all current logs from ramdisk to SD card so we don't hit the same ignored line multiple times
        sync_logs
        # F stands for force session start.
        # echo ? to the same procfs endpoint will send command list to the syslog.
        echo "F" > /proc/driver/musb_hdrc.0
    fi
}

send_logs_and_reboot() {
    local LOG_MSG="$1"
    local ERR_CODE="$2"
    syslog_line daemon.info "Event=WatchdogRebootEvent Msg=${ERR_CODE}"
    echo "=========================================" >> ${REBOOT_DEBUG}
    echo "$(date) $(cat /etc/etm-serial) Watchdog Reboot" >> ${REBOOT_DEBUG}
    echo "=========================================" >> ${REBOOT_DEBUG}
    echo "${LOG_MSG}" >> ${REBOOT_DEBUG}
    # sync logs to move all current logs from ramdisk to SD card so we don't hit the same problem line multiple times
    sync_logs
    # upload logs to e.com
    /etm/bin/etmcrash.sh > /dev/null 2>&1
    force_reboot "${ERR_CODE}"
}

# check syslog for a trouble indication and reboot if found
reboot_if_syslog_error() {
    local ERR_MSG="$1"
    local LOG_MSG="$2"
    local ERR_CODE="$3"
    grep -e "${ERR_MSG}" "${SYSLOG_TMPFS_FILE}" > /dev/null 2>&1
    if [ $? == "0" ]; then
        syslog_line daemon.info "Event=WatchdogRebootEvent ErrCode=${ERR_CODE}"
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "$(date) $(cat /etc/etm-serial) Watchdog Reboot" >> ${REBOOT_DEBUG}
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "${LOG_MSG}" >> ${REBOOT_DEBUG}
        grep "${ERR_MSG}" "${SYSLOG_TMPFS_FILE}" >> ${REBOOT_DEBUG}

        # sync logs to move all current logs from ramdisk to SD card so we don't hit the same ignored line multiple times
        sync_logs
        # upload logs to e.com
        /etm/bin/etmcrash.sh > /dev/null 2>&1
        force_reboot "${ERR_CODE}"
    fi
}

# check syslog for unknown device error message from USB subsystem
reboot_if_unknown_usb_error() {
    local ERR_MSG_1="$1"
    local ERR_MSG_2="$2"
    local ERR_MSG_3="$3"
    local LOG_MSG="$4"
    local DEV_ERR_USB="user.err kernel:.* usb"
    local DEV_ERR_HUB="user.err kernel:.* hub"

    # v - invert match. grep items that doesn't match the pattern
    grep -v "${ERR_MSG_1}" "${SYSLOG_TMPFS_FILE}" | grep -v "${ERR_MSG_2}" | grep -v "${ERR_MSG_3}" | grep -e "$DEV_ERR_USB" -e "$DEV_ERR_HUB" > /dev/null 2>&1
    if [ $? == "0" ]; then
        # log current lsusb state before execute etmcrash and reboot.
        syslog_line daemon.info "Event=lsusb State={$(/usr/bin/lsusb | /usr/bin/tr '\n' ',')}"
        syslog_line daemon.info "Event=WatchdogRebootEvent ErrCode=UnknownUsbError Data=${LOG_MSG}"
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "$(date) $(cat /etc/etm-serial) Watchdog Reboot" >> ${REBOOT_DEBUG}
        echo "=========================================" >> ${REBOOT_DEBUG}
        echo "${LOG_MSG}" >> ${REBOOT_DEBUG}
        # e - regular expression. Used to specify multiple search patterns
        grep -v "${ERR_MSG_1}" "${SYSLOG_TMPFS_FILE}" | grep -v "${ERR_MSG_2}" | grep -v "${ERR_MSG_3}" | grep -e "$DEV_ERR_USB" -e "$DEV_ERR_HUB" >> ${REBOOT_DEBUG}

        # sync logs to move all current logs from ramdisk to SD card so we don't hit the same ignored line multiple times
        sync_logs
        # upload logs to e.com
        /etm/bin/etmcrash.sh > /dev/null 2>&1
        force_reboot "unknown-usb-err"
    fi
}

# check syslog for trouble indications and reboot if found
check_syslog() {

    # CAUTION:  The message inserted in the syslog (below) must not match any of these regular expressions.
    # old message "kernel: FAT: Directory bread "
    # new message Dec  4 18:20:10 var-som-am33 user.err kernel: [ 2183.253509] FAT-fs (sda1): Directory bread(block 3835) failed

    local ERRSTR_FAT="FAT.*: Directory bread.*failed"
    local ERRSTR_FAT2="FAT.*: FAT read failed"
    # example: Oct 16 16:09:55 taser-etmv2 user.err kernel: [170173.680358] FAT-fs (sda1): error, invalid access to FAT (entry 0xa4103127)
    local ERRSTR_FAT3="FAT.*: error, invalid access to FAT"
    local ERRSTR_OS="Kernel bug detected"
    local ERRSTR_OOPS="Internal error: Oops:.*"
    local ERRSTR_IOCTL="print_req_error: I/O error, dev sd.*, sector .*"
    local ERRSTR_DEVICE_DESCRIPTOR="usb .*: device descriptor read/.*, error .*"
    local ERRSTR_DEVICE_ADDRESS="usb .*: device not accepting address .*, error .*"
    local ERRSTR_BABBLE="musb-hdrc .*: Babble"

    local ERRSTR_VBUS="VBUS error workaround"
    local ERRSTR_IO_ERR="sd.*: rejecting I/O to offline device"
    local ERRSTR_DEVICE_ENUM="usb .*: unable to enumerate USB device"
    # Splunk query over last 30 days for daemon.err udev showed ~20 events including daemon.err udevd-work, which we don't know to be fatal.
    # Using "daemon.err udevd[" as the regular expression to avoid the udevd-work errors.
    local ERRSTR_UDEV_ERR="daemon.err udevd\["
    # splunk shows no instances since the 2.0a revision, but adding as a defense in depth.
    local ERRSTR_OOM_KILLER_ERR="invoked oom-killer"
    # this error shows up with Axon 2 cameras when libusb returns busy where it should not be. The dock can't talk to
    # the cameras when busy error occurs.
    local ERRSTR_USB_INTERFACE_CLAIMED="usbfs: interface .* claimed by usbfs while 'adm_tool' .*"
    local ERRSTR_LIBUSB_ERROR_BUSY="LIBUSB_ERROR_BUSY"

    if [ -f "${SYSLOG_TMPFS_FILE}" ]; then
        # priority order: reboots first because each action clears the logs for the ones below
        reboot_if_syslog_error "$ERRSTR_OS" "Kernel bug found!" "kernel-bug-found"
        reboot_if_syslog_error "$ERRSTR_IO_ERR" "Rejected I/O error detected!" "rejected-io"
        reboot_if_syslog_error "$ERRSTR_OOPS" "Kernel oops detected!" "kernel-oops"
        reboot_if_syslog_error "$ERRSTR_UDEV_ERR" "udevd failure detected!" "udevd-failure"
        reboot_if_syslog_error "$ERRSTR_OOM_KILLER_ERR" "Out of Memory failure detected!" "low-memory"
        reboot_if_syslog_error "$ERRSTR_USB_INTERFACE_CLAIMED" "USB Interface Busy" "USB-interface-claimed"
        reboot_if_syslog_error "$ERRSTR_LIBUSB_ERROR_BUSY" "USB Interface Busy" "USB-interface-busy"

        # Error messages that are printed using dev_err() are appended with "user.err kernel:" when it comes
        # to userspace. Reboot ETM if syslog file has new messages with identifier "user.err kernel:.* usb" and/or
        # "user.err kernel:.* hub".
        # reboot_if_dev_error() will filter out the above messages and look for new device error messages with the
        # above specified prefixes. Note: dev_err() is a diagnostic helper function used by kernel drivers.
        # As we don't know the list of USB errors that requires ETM reboot, as a precautionery measure, this script
        # will reboot the ETM if a new/unknown USB error message is detected.

        reboot_if_unknown_usb_error "$ERRSTR_DEVICE_DESCRIPTOR" "$ERRSTR_DEVICE_ADDRESS"  "$ERRSTR_DEVICE_ENUM" "USB_UnknownErrorMessageDetected"

        re_enumerate_if_syslog_error "$ERRSTR_DEVICE_ENUM"

        # unmount any devices that might be missing with stale mounts
        # do this before cleaning the log below
        if ! /etm/bin/unmount-missing-devices.sh; then
            send_logs_and_reboot "unmount-missing-devices.sh failed!" "fail-unmount-missing-devices"
        fi
        # log any FAT errors and reset the logs so cleanup doesn't run multiple times.
        log_if_syslog_error "$ERRSTR_FAT" "FAT_DirectoryReadFailure"
        log_if_syslog_error "$ERRSTR_FAT2" "FAT_FatReadFailure"
        log_if_syslog_error "$ERRSTR_FAT3" "FAT_InvalidFatAccessFailure"

        # if we are a debug build, keep these logs records for easier analysis
        if [ $ETM_DEBUG_BUILD ]; then

            # system reboot are not required for the following error messages, as the ETM itself will
            # recover from them. USB ioctl error are common while unplugging the device while host is
            # uploading device files. This message originated from block/blk-core.c
            log_if_syslog_error "$ERRSTR_IOCTL" "IOCTL_BlockError"

            # Device descriptor, device address error will happen if the device is unplugged while host enumerating.
            # ETM will recover by itself, so don't reboot. This message originated from drivers/usb/core/hub.c
            log_if_syslog_error "$ERRSTR_DEVICE_DESCRIPTOR" "USB_DeviceDescriptorError"
            log_if_syslog_error  "$ERRSTR_DEVICE_ADDRESS" "USB_DeviceAddressError"

            # Babble error occurs when the endpoint receives more data than the endpoint's specified maximum packet size.
            # This will happen when there is an electrical/EMI noise or spurious interrupts generated by faulty cables.
            # The USB driver will recover from such error by restarting musb. This message comes from
            # drivers/usb/musb/musb_core.c
            log_if_syslog_error "$ERRSTR_BABBLE" "USB_BabbleError"
        fi
    fi
}

check_etmd() {
    # pid file means the etm was started at one point
    if [ -f $PID_FILE ]; then
        # [segfault check] look for etmd process, start it if it's not there...
        local PID=$(cat $PID_FILE)
        local PID_CHECK=$(ps -A | awk '{print $1;}' | grep $PID)
        if [ -z $PID_CHECK ]; then PID_CHECK=0; fi
        if [ $PID != $PID_CHECK ]; then
            syslog_line daemon.warning "Event=ETMD_Process_Missing Action=SyncLogs"
            sync_logs
            syslog_line daemon.warning "Event=ETMD_Process_Missing Action=SendLogs"
            /etm/bin/etmcrash.sh > /dev/null 2>&1
            syslog_line daemon.warning "Event=ETMD_Process_Missing Action=RestartETMD"
            echo "=========================================" >> ${RESTART_DEBUG}
            echo "$(date) $(cat /etc/etm-serial) Watchdog Restart Crashed etmd" >> ${RESTART_DEBUG}
            echo "=========================================" >> ${RESTART_DEBUG}
            echo "ETM daemon process not found. Last 40 lines of etmd log:" >> ${RESTART_DEBUG}
            tail -40  ${UPLOAD_LOG} >> ${RESTART_DEBUG}
            /etc/init.d/etm.sh restart
            sleep 20
        fi

        # [hung check] check if the /tmp/etm.state file is older than 4 min...
        if [ -f $STATE_FILE ]; then
            local NOW=$(date +%s)
            local ETM_LAST_MOD=$(date -r $STATE_FILE +%s)
            if [ $(( $NOW - $ETM_LAST_MOD )) -gt 240 ]; then
                syslog_line daemon.warning "Event=ETMD_Process_Hung Action=SyncLogs"
                sync_logs
                syslog_line daemon.warning "Event=ETMD_Process_Hung Action=SendLogs"
                /etm/bin/etmcrash.sh > /dev/null 2>&1
                syslog_line daemon.warning "Event=ETMD_Process_Hung Action=Reboot"
                echo "=========================================" >> ${RESTART_DEBUG}
                echo "$(date) $(cat /etc/etm-serial) Watchdog Restart Hung etmd" >> ${RESTART_DEBUG}
                echo "=========================================" >> ${RESTART_DEBUG}
                echo "ETM daemon process hung. Last 40 lines of etmd log:" >> ${RESTART_DEBUG}
                tail -40 ${UPLOAD_LOG} >> ${RESTART_DEBUG}

                force_reboot "etmd-hang"
            fi
        fi

        # OOM check.
        grep -F -e "The process failed to start. Resource error (fork failure): Cannot allocate memory" "${SYSLOG_TMPFS_FILE}" > /dev/null 2>&1
        if [ $? == "0" ]; then
            ps aux | grep -F "${ETMD}" | grep -v grep | logger -s -p daemon.info -t etm-watchdog
            syslog_line daemon.warning "Event=ETMD_Process_OOM Action=SyncLogs"
            sync_logs
            syslog_line daemon.warning "Event=ETMD_Process_OOM Action=SendLogs"
            /etm/bin/etmcrash.sh > /dev/null 2>&1
            syslog_line daemon.warning "Event=ETMD_Process_OOM Action=RestartETMD"
            echo "=========================================" >> ${RESTART_DEBUG}
            echo "$(date) $(cat /etc/etm-serial) Watchdog Restart OOM etmd" >> ${RESTART_DEBUG}
            echo "=========================================" >> ${RESTART_DEBUG}
            echo "ETM daemon process OOM. Last 40 lines of etmd log:" >> ${RESTART_DEBUG}
            tail -40  ${UPLOAD_LOG} >> ${RESTART_DEBUG}
            /etc/init.d/etm.sh restart
            sleep 20
        fi
    fi
}

check_ssl() {
    /etc/init.d/etm-gen-cert.sh --force-ip-check
    if [ $? -eq 2 ] ; then
        /etc/init.d/lighttpd restart
    fi
}

check_lighttpd_monitord() {
    local RUN_COUNT=$(pgrep -f etm-lighttpd-monitord.sh | wc -l)
    if [ ${RUN_COUNT} -eq 0 ] ; then
        /etc/init.d/etm-lighttpd-monitor.sh start
    fi
}

dump_memory_info() {
    free | logger -s -p daemon.info -t etm-watchdog.sh
}

sync_logs() {
    # synchronize logs, handle errors, update the timestamp in LOGS_SYNC_TS (variable) and LOGS_SYNC_TS_FILE (file)

    # create a temporary to catch sync-etm-log.sh' output, it will be removed after use
    local OUTPUT_TMP="$(mktemp -t XXXXXX 2>/dev/null)"
    if [[ -z "${OUTPUT_TMP}" ]]; then
        syslog_line "daemon.emerg" "Event=FailOutputRedirect_sync-etm-log Action=OutputIgnored"
        OUTPUT_TMP="/dev/null"
    fi

    /etm/bin/sync-etm-log.sh > "${OUTPUT_TMP}" 2>&1
    local RC=$?

    if [[ "${RC}" -ne 0 ]]; then
        syslog_line "daemon.emerg" "Event=ErrorDuringLogSync"
    fi

    if [[ "${OUTPUT_TMP}" != "/dev/null" ]]; then
        # if there is something in the output then dump it to the syslog
        if [[ -s "${OUTPUT_TMP}" ]]; then
            dump_to_syslog "sync_logs" "${RC}" "${OUTPUT_TMP}"
        fi

        rm -f "${OUTPUT_TMP}"
    fi

    # update sync timestamp in LOGS_SYNC_TS (variable) and also in LOGS_SYNC_TS_FILE (file)
    LOGS_SYNC_TS="$(date +%s 2>/dev/null)"
    echo "${LOGS_SYNC_TS}" > "${LOGS_SYNC_TS_FILE}"
    if [[ "$?" -ne 0 ]]; then
        syslog_line daemon.emerg "Event=UnableCreateTimestampFile File=${LOGS_SYNC_TS_FILE}"
    fi
}

# handle SIGINT and SIGTERM to prevent termination in the middle of doing something important
TERMINATE_ETM_WATCHDOG=0

exit_handler() {
    TERMINATE_ETM_WATCHDOG=1
}

trap exit_handler SIGINT SIGTERM SIGHUP

RUN_COUNT=$(ps -A | grep etm-watchdog.sh | wc -l)

# why 2?
# because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
# no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
if [ $RUN_COUNT -gt 2 ]; then
    log_info "Event=EtmWatchdogAlreadyRunning Action=exit"
    exit 2
fi

# set our OOM killer adjustments to be as low priority as possible
echo -1000 > /proc/$$/oom_score_adj

syslog_line daemon.info "Event=EtmWatchdogStart"

LOGS_SYNC_TS=
if [[ -f "${LOGS_SYNC_TS_FILE}" ]]; then
   LOGS_SYNC_TS="$(cat "${LOGS_SYNC_TS_FILE}" 2>/dev/null)"
fi

if [[ -z "${LOGS_SYNC_TS}" ]]; then
    syslog_line daemon.emerg "Event=UnableReadLogSyncTimestamp File=${LOGS_SYNC_TS_FILE}"
    # sync right now, it will automatically update the timestamp file
    sync_logs
fi

COUNT=0

while [ "${TERMINATE_ETM_WATCHDOG}" -eq 0 ]; do

    write_now_timestamp ${SERVICE_NAME} "${ETMWATCHDOG_TS_FILE}"

    handle_web_requests
    check_rootfs
    check_syslog
    check_etmd
    check_ssl
    check_lighttpd_monitord

    # limit logs synchronization to LOGS_SYNC_INTERVAL since previous sync
    LOGS_SYNC_TS_DELTA=$(($(date +%s 2>/dev/null) - ${LOGS_SYNC_TS}))
    # in the following comparison an absolute value of $LOGS_SYNC_TS_DELTA is used, so the situation
    # when system clock was set to some time in the past will be handled propertly and logs will be synchronized.
    # For example:
    # date of previous sync is Jun 01, 2014 00:00:00, then at 00:02:00 somebody sets system date to
    # Jan 01, 2014 00:02:00 so without using abs of LOGS_SYNC_TS_DELTA it will be pretty big negative number
    # and next sync will be in several months...
    if [[ "${LOGS_SYNC_TS_DELTA#-}" -ge "${LOGS_SYNC_INTERVAL}" ]]; then
        sync_logs
    fi

    # limit logging to every 180 seconds, to save space in the logs
    # without reducing frequency. Log the free memory at the same time.
    COUNT=$((COUNT+1))
    if [ $COUNT -ge 12 ]; then
        dump_memory_info
        syslog_line daemon.info "Event=EtmWatchdogSleeping"
        COUNT=0;
    fi

    clear_now_timestamp "${ETMWATCHDOG_TS_FILE}"

    sleep 15
done
