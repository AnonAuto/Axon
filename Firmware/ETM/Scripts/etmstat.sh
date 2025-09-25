#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
. /etm/bin/etm-common.sh

SERVICE_NAME=etmstat.sh

# agency for DNS and HTTPS tests.  Overwritten with actual agency if dock
# is registered.
AGENCY_FQDN=prod.evidence.com

# if test mode is set, then don't send status to e.com
TEST_MODE=0
if [ "$1" == "test" ]; then
    TEST_MODE=1
fi

echo "Running ${SERVICE_NAME}"

# set debug prefix is a space
# debug function is in uci-functions.sh (sourced by etm-common.sh)
DEBUG="echo -e \040"

ping_check() {
    echo $(ping -c 2 -q -w 5 $1 | awk '/packets/ {printf "%d", $1 - $4}; /round-trip/ {printf "/%s", $4}')
}

dns_check() {
    echo $(host -W 3 ${AGENCY_FQDN} $1 | grep "has address" | awk '{print $4}')
}

https_check() {
    echo $(curl -sw "%{http_code}/%{time_total}" -o /dev/null -m 15 --cacert ${SSL_CA_BUNDLE} https://${AGENCY_FQDN}/ping)
}

write_status_and_exit () {
    # $1 = return code
    # $2 = optional parameter for etm-status (whether to transmit the data)
    uci_commit network
    uci_commit etm

    make_tmp_status_config
    /etm/bin/etm-status $2 /tmp/status.config
    log_elapsed_time ${SERVICE_NAME}

    # remove it because we check it against a timeout based on the run time of this script, not the cron schedule for this script,
    # so absence indicates "success", that is not a hang.
    clear_now_timestamp "${ETMSTAT_TS_FILE}"

    exit $1
}

error_out() {
    # in the error case, we don't have connection to E.com, so no point in trying to send it.
    write_status_and_exit 1 -n
}

fail_if_empty() {
    if [ -z $1 ]; then
        error_out
    fi
}

# reset_state() should attempt to fill these variables
WAN_UP=""
WAN_IP=""
GW_IP=""
DNS_IP=""

# these will be set by system checks
GW_PING=""
DNS_PING=""
DNS_LOOKUP=""
HTTPS_CHECK=""

# This function is duplicate of create_uci_state in etm-prep.sh
# here is it used to create a blank state file so the state files don't
# grow indefinitely.
# TODO_IDEA: deduplicate code
# Deleting these files on each status pass has one potential flaw:
# A simultaneous read of these files from the WebUI while this
# script is running might return incomplete data. But then again,
# that's possible with the previous code and was probably even more
# likely then.

create_clear_uci_state() {

    OLD_NTP_CHECK=
    # if a state file exists, move it to the backup and
    # start a new file
    if [ -f $STATE_DIR/etm ]; then
        # Save the NTP status (if any) from the backup file to the current file
        # this is currently the only status bit that is not reset by this file.
        # Done this way without depending on UCI for performance reasons if we are
        # repairing a big (slow) state file
        OLD_NTP_CHECK="$(uci_get_state etm status ntpcheck)"

        if [ -f $STATE_DIR/etm.bak ]; then
            rm $STATE_DIR/etm.bak
        fi
        mv $STATE_DIR/etm $STATE_DIR/etm.bak
    fi

    # ditto for network
    if [ -f $STATE_DIR/network ]; then
        if [ -f $STATE_DIR/network.bak ]; then
            rm $STATE_DIR/network.bak
        fi
        mv $STATE_DIR/network $STATE_DIR/network.bak
    fi

    # create status section since the file is gone
    local SECTION=$(/sbin/uci -P $STATE_DIR add etm etm-status)
    /sbin/uci -P $STATE_DIR rename etm.${SECTION}=status

    # replay the NTP value if any
    if [ ! -z ${OLD_NTP_CHECK} ]; then
        /sbin/uci -P $STATE_DIR set etm.status.ntpcheck=${OLD_NTP_CHECK}
    fi
}

reset_state() {

#    LOAD_STATE=1
#    PATH=/bin:$PATH

    # create the config file UCI requires to address the network package
    if [ ! -f /etc/config/network ]; then
        logger -s -p daemon.error -t ${SERVICE_NAME} "Creating network configuration file that is missing!"
        echo > /etc/config/network
    fi

    /sbin/ifconfig $WAN_IFACE | grep -q UP
    if [ $? = 0 ]; then
        WAN_UP=1
    else
        WAN_UP=0
    fi
    WAN_IP=$(/sbin/ifconfig $WAN_IFACE | grep inet | awk '{print $2}' | sed  -e "s/addr://")
    WAN_MASK=$(/sbin/ifconfig $WAN_IFACE | grep inet | awk '{print $4}' | sed  -e "s/Mask://")
    GW_IP=$(/bin/ip route | grep "^default" | awk '{print $3}')
    DNS_IP=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr '\n' ' ')
    awk -f /etm/bin/queryInterfaces.awk /etc/network/interfaces device=${WAN_IFACE} | grep -e "proto static"
    if [ $? == "0" ]; then
        WAN_PROTO=static
    else
        WAN_PROTO=dhcp
    fi
    local WAN_MAC=$(/sbin/ifconfig -a | grep $WAN_IFACE | awk '{print $5}')
    local LAN_MAC=$(/sbin/ifconfig -a | grep $LAN_IFACE | awk '{print $5}')

    # clear the state by deleting the files (instead of just deleting the values)
    create_clear_uci_state

    # create relevant sections
    local SECTION=$(/sbin/uci -P $STATE_DIR add network interface)
    /sbin/uci -P $STATE_DIR rename network.${SECTION}=wan
    SECTION=$(/sbin/uci -P $STATE_DIR add network interface)
    /sbin/uci -P $STATE_DIR rename network.${SECTION}=lan
    uci_commit network

    # write what we know
    set_network_state wan ifname "$WAN_IFACE"
    set_network_state wan device "$WAN_IFACE"
    set_network_state wan ipaddr "$WAN_IP"
    set_network_state wan gateway "$GW_IP"
    set_network_state wan netmask "$WAN_MASK"
    set_network_state wan dns "$DNS_IP"
    set_network_state wan up "$WAN_UP"
    set_network_state wan proto "$WAN_PROTO"

    set_network_state lan ifname "$LAN_IFACE"
    set_network_state lan proto "static"
    set_network_state lan ipaddr "10.10.1.1"
    set_network_state lan netmask "255.255.255.0"

    # rewrite basic ETM values read by the WebUI
    set_etm_state "wlan_iface" "$WAN_IFACE"
    set_etm_state "wlan_mac" "$WAN_MAC"
    set_etm_state "lan_iface" "$LAN_IFACE"
    set_etm_state "lan_mac" "$LAN_MAC"
    set_etm_state "serial" "$SN"

    echo WAN, GW, DNS = $WAN_IP, $GW_IP, $DNS_IP
}

set_network_state() {
    echo set network.$1.$2 = $3
    uci_set_state network $1 $2 "$3"
}

set_etm_state() {
    echo set $1 = $2
    uci_set_state etm status $1 "$2"
}

stat_ip() {
    debug IP

    if [ "$WAN_UP" != "1" ]
    then
        set_etm_state ipaddr down
        error_out
    fi

    if [ -z $WAN_IP ]; then
        set_etm_state gwping "NA"
        set_etm_state dnsaddr_1 "NA"
        set_etm_state dnsping_1 "NA"
        set_etm_state dnschk_1 "NA"
        error_out
    fi

    set_etm_state ipaddr "${WAN_IP:-0.0.0.1}"
}

stat_gateway() {
    debug GW
    GW_PING=$(ping_check ${GW_IP:-0.0.0.1})

    set_etm_state gwaddr "${GW_IP:-0.0.0.1}"
    set_etm_state gwping "${GW_PING:-NA}"

    fail_if_empty $GW_IP
}

stat_dns() {

    debug DNS
    i=1
    for ip in $DNS_IP; do
        DNS_PING=$(ping_check ${ip:-0.0.0.1})

        # BWE-2813: There is a case where customer's DNS servers (sent by DHCP server) does not resolve external IPs,
        # but the proxy server can. The consequence is `curl --proxy <proxy-server> https://time.evidence.com/ping`
        # works (because proxy-server is the one that resolve doamain `time.evidence.com`) but `host time.evidence.com` fails.
        # The solution is to let user disable this dns check if `etm.proxy.disable_dns_check` flag is set to true.
        if [ "${DISABLE_DNS_CHECK}" = "0" ]; then
            DNS_LOOKUP=$(dns_check ${ip:-0.0.0.1})
        else
            DNS_LOOKUP="NA"
        fi

        set_etm_state dnsaddr_${i} "${ip:-0.0.0.1}"
        set_etm_state dnsping_${i} "${DNS_PING:-NA}"
        set_etm_state dnschk_${i} "${DNS_LOOKUP:-NA}"
        let i=i+1
    done

    fail_if_empty $DNS_IP
}

stat_https() {
    debug HTTPS
    HTTPS_CHECK=$(https_check)

    set_etm_state httpscheck "${HTTPS_CHECK:-NA}"
}

stat_corruption() {
    local TIMEOUT=30
    # pid is the process being watched for timeout
    local $pid
    # watcher is the pid of the timeout process so it can
    # be shutdown if the watched process exits more quickly
    local $watcher
    (
        ( find /mnt/etm -name *bad* > /tmp/corruption 2>/dev/null ) & pid=$!
        ( sleep $TIMEOUT && ( kill -HUP $pid && log_err_msg ${SERVICE_NAME} "Timeout checking for corrupt files" ) ) 2>/dev/null & watcher=$!
        wait $pid 2>/dev/null && pkill -HUP -P $watcher
    )
}

SEND_IT=
query_send() {
    SEND_IT=
    if [ ${TEST_MODE} == "1" ]; then
        SEND_IT=-n
    fi

    if [ $(/sbin/uci get etm.etm.send_status) = "0" ]; then
        SEND_IT=-n
    fi

    /sbin/uci get etm.operation.agency_domain
    if [ $? -ne 0 ]; then
        SEND_IT=-n
    fi

}

update_FAT_partition() {
    # create a temporary directory and mount the boot partition of the SD card
    local TMP_MNT_DIR="/boot-fat"
    local WL_FILE="${TMP_MNT_DIR}/wl_trigger.dat"

    if [ ! -d "${TMP_MNT_DIR}" ]; then
        mkdir -m 0700 "${TMP_MNT_DIR}"
        if [ ! -d "${TMP_MNT_DIR}" ]; then
            # send "unable to create temporary directory" critical alert
            send_critical_alert "${SERVICE_NAME}" "sdcard-upd-fat-tmpdir"
            return 1
        fi
    fi

    # this variable prevents us from unmounting boot (FAT) partition if it was mounted outside this script
    local MOUNTED_HERE=0

    # check if boot(FAT) partition of the SD card is already mounted
    if ! mount 2>/dev/null | grep "${TMP_MNT_DIR}" ; then
        # TMP_MNT_DIR is not in the list of mount points, mount boot partition there
        if ! mount -t vfat -o noatime /dev/mmcblk0p1 "${TMP_MNT_DIR}" ; then
            # send "unable to mount the boot partition of the SD card" critical alert
            send_critical_alert "${SERVICE_NAME}" "sdcard-upd-fat-mnt"
            return 1
        else
            log_info_msg "${SERVICE_NAME}" "mounted boot partition of the SD card to ${TMP_MNT_DIR}"
            MOUNTED_HERE=1
        fi
    fi

    # re-write WL_FILE file on the boot(FAT) partition to trigger wear leveling on the card
    rm -rf "${WL_FILE}" && sync
    # write 2k of random data to the file
    dd if=/dev/urandom bs=2048 count=1 of="${WL_FILE}" && sync

    # un-mount the boot partition of the SD card
    if [[ ${MOUNTED_HERE} -eq 1 ]] ; then
        if umount ${TMP_MNT_DIR}; then
            log_info_msg "${SERVICE_NAME}" "unmounted boot folder"
            MOUNTED_HERE=0
        else
            log_err_msg "${SERVICE_NAME}" "sdcard-upd-fat-bad-umount"
        fi
    fi

    log_info_msg "${SERVICE_NAME}" "updated file on the boot(FAT) partition"
    return 0
}

# Limit to a single instance (do not use SERVICE_NAME which is subject to being a friendly name)
RUN_COUNT=$(ps -A | grep etmstat.sh | wc -l)

# why 2?
# because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
# no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
if [ $RUN_COUNT -gt 2 ]; then
    log_info_msg ${SERVICE_NAME} "${SERVICE_NAME} already running, exiting..."
    exit 2
fi

# for test mode - inject a delay long enough to ensure we can launch multiple instances at the same time before the first one exits
if [ ${TEST_MODE} == "1" ]; then
    sleep $2
fi

#### MAIN ####

# save timestamp to detect a hang:
write_now_timestamp ${SERVICE_NAME} "${ETMSTAT_TS_FILE}"

# update file on the boot (FAT) partition of the card to trig wear leveling
update_FAT_partition

touch /tmp/corruption

# set timestamp
START=$(date +'%Y-%m-%d %H:%M:%S')

config_load etm
config_get AGENCY operation agency_domain
config_get_bool DISABLE_DNS_CHECK proxy disable_dns_check 0

if [ ! -z ${AGENCY} ]; then
    AGENCY_FQDN=${AGENCY}
fi

reset_state

set_etm_state timestamp "${START}"

# interface is up and IP is assigned
stat_ip

# we have a gateway and it can be pinged
stat_gateway

# we have a DNS server and prod.evidence.com can be resolved
stat_dns

# HTTPS access to prod.evidence.com is available
stat_https

# Time Server is processed using set-rtc.sh

# evidence.com registration (if not stand alone) is checked inside etm-status

# rebuild file corruption list
stat_corruption

# set $SEND_IT parameter
query_send

write_status_and_exit 0 $SEND_IT
