#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Limit bandwidth on WAN_IFACE.
#
# Credit: based on http://serverfault.com/questions/242432/bash-script-traffic-shaping

# Name of this script (for logging)
THIS_SCRIPT=etm-traffic

. /etm/bin/etm-common.sh

# The traffic control tool
TC=/sbin/tc

# we use Token Bucket Filter to control traffic.  "man tbf" for details.

start_tbf() {
    local KBYTE_RATE=$1
    # see TBF documentation for rationale behind these formulas.  These
    # are rough, and conservative - favoring performance.  Smaller values can
    # be used but might limit performance.
    local BURST=$(( KBYTE_RATE / 10 ))
    local LIMIT=$(( BURST * 2 ))

    # ensure there isn't anything on the interface
    ${TC} qdisc del dev ${WAN_IFACE} root
    # set tbf to the configured speed.  burst and limit are configured to allow
    ${TC} qdisc add dev ${WAN_IFACE} root tbf rate ${KBYTE_RATE}kbps burst ${BURST}kb limit ${LIMIT}k

    if [ $? -eq 0 ]; then
        log_info_msg ${THIS_SCRIPT} "Event=SetBandwidthLimit KBps=${KBYTE_RATE}"
    else
        log_info_msg ${THIS_SCRIPT} "Event=ErrorSettingBandwidthLimit KBps=${KBYTE_RATE}"
    fi
}

start() {

    # compute kilo-byte-per-second rate from bits per second value in the config file
    config_load etm
    config_get THROTTLE_KBITPS etm netlimit_kbitps

    if [[ -z ${THROTTLE_KBITPS} ]] ||
       [[ ${THROTTLE_KBITPS} -eq 0 ]]; then
        log_info_msg ${THIS_SCRIPT} "Event=NoBandwidthLimitSet"
        stop
    else

        local KBYTE_RATE=$(( THROTTLE_KBITPS / 8 ))

        # double check result
        # require  to 40MBps, which translates to
        # 500Kbps (62 KBps) up to 40MBps.
        # @ 600 Mhz the dock can transfer ~19MBps (152Mbps).  Assuming faster ones will get up to a maximum of 40MBps.
        if [ ${KBYTE_RATE} -ge 62 ] && [ ${KBYTE_RATE} -le 40000 ]; then
            start_tbf ${KBYTE_RATE}
        else
            # if the limit is out of this range we just remove it and don't throttle.
            log_err_msg ${THIS_SCRIPT} "Event=InvalidBandwidthLimit Limit=${THROTTLE_KBITPS} KBps=${KBYTE_RATE}"
            stop
            send_critical_alert ${THIS_SCRIPT} "InvalidBandwidthLimit"
        fi
    fi
}

stop() {
    # Stop bandwidth throttling.
    log_info_msg ${THIS_SCRIPT} "Event=BandwidthLimitingStopped"
    $TC qdisc del dev ${WAN_IFACE} root
}

restart() {
    stop
    sleep 1
    start
}

show() {
    # Display status
    $TC -s qdisc ls dev ${WAN_IFACE}
}

case "$1" in

  start)

    log_info_msg ${THIS_SCRIPT} "Event=StartingBandwidthThrottling"
    start
    echo "done"
    ;;

  stop)

    log_info_msg ${THIS_SCRIPT} "Event=StoppingBandwidthThrottling"
    stop
    echo "done"
    ;;

  restart)

    log_info_msg ${THIS_SCRIPT} "Event=RestartingBandwidthThrottling"
    restart
    echo "done"
    ;;

  show)

    echo "Bandwidth status for ${WAN_IFACE}:"
    show
    echo ""
    ;;

  *)

    pwd=$(pwd)
    echo "Usage: etm-traffic.sh {start|stop|restart|show}"
    ;;

esac

exit 0
