#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

# import global constants and configuration
. /etm/bin/etm-common.sh

# RANDOM_OFFSET_SECOND_START
ROCS=$(/etm/bin/ecom-admin n 1 30)

# This script includes commands that are required for proper ETM operation but
# we need to run them once during a boot time

echo "Running etm-prep.sh (preparing ETM for operation)"

# export our GPIO controls and clear the capacitors on the hubs
# by ensuring a long power-down cycle
initialize_USB_GPIO() {
    # We unbind connection between USB0 and musb-hdrc before turning off VBUS to avoid instability.
    echo ${USB0_MUSB_HDRC_INSTANCE} > ${MUSB_HDRC_DRIVER_CONTROL_PATH}/unbind
    echo ${GPIO_USB0} > ${GPIO_PATH}/export

    logger -s -p daemon.error -t "etm-prep" "Disabling USB Power to reset all devices"
    echo out > ${GPIO_USB0_PATH}/direction
    # shutdown the USB chain
    echo 0 > ${GPIO_USB0_PATH}/value
    # wait for all caps to discharge
    logger -s -p daemon.error -t "etm-prep" "Waiting for 45 seconds"
    # trigger LED notification on SOM board and 45 second wait
    /etm/bin/led-ctrl -b -d 45 green

    # BWE-2723: add random delay for not overwhelming e.com
    # wait for a random seconds
    logger -s -p daemon.error -t "etm-prep" "Waiting for another $ROCS seconds"
    # trigger LED notification on SOM board and random second wait
    /etm/bin/led-ctrl -b -d $ROCS green

    # re-enable it
    logger -s -p daemon.error -t "etm-prep" "re-enabling USB Power to reset all devices"
    echo 1 > ${GPIO_USB0_PATH}/value
    # Rebind USB0 to musb-hdrc
    echo ${USB0_MUSB_HDRC_INSTANCE} > ${MUSB_HDRC_DRIVER_CONTROL_PATH}/bind
}

create_uci_state() {
    # if a state file exists, move it to the backup and
    # start a new file
    if [ -f $STATE_DIR/etm ]; then
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

    # create status section if it doesn't exist
    local SECTION=$(/sbin/uci -P $STATE_DIR add etm etm-status)
    /sbin/uci -P $STATE_DIR rename etm.${SECTION}=status
}

init_etm_status() {
    #print out the WAN IP address to syslog at startup
    get_ip_address "${WAN_IFACE}" "etm-prep"

    local LAN_MAC=$(ifconfig -a | grep $LAN_IFACE | awk '{print $5}')
    local WAN_MAC=$(ifconfig -a | grep $WAN_IFACE | awk '{print $5}')

    echo Booting ETM Serial \# $SN @ WAN: $WAN_MAC, LAN: $LAN_MAC

    uci_set_state "etm" "status" "wlan_iface" "$WAN_IFACE"
    uci_set_state "etm" "status" "wlan_mac" "$WAN_MAC"
    uci_set_state "etm" "status" "lan_iface" "$LAN_IFACE"
    uci_set_state "etm" "status" "lan_mac" "$LAN_MAC"
    uci_set_state "etm" "status" "serial" "$SN"
    uci_commit etm
}

case "$1" in
    start)
        /etm/bin/update-passwd.sh

        echo Initializing USB GPIO
        initialize_USB_GPIO
        
        echo Initializing UCI configuration...
        config_load etm
        # initialize status file 
        create_uci_state
        # update state with network MAC addresses, serial number
        init_etm_status

        ## set up proxy config
        proxy_generate_runtime_config

        if [ $ETM_DEBUG_BUILD ]; then
            /etm/bin/enable-dynamic-debug.sh
        fi

        # Run RTC update script with 'force' option which will cause it to synchronize
        # clock with one of the remote servers
        echo Synchnonizing clock...
        /etm/bin/set-rtc.sh force

        # schedule the startup firmware update without blocking 
        if [ ${ETM_DEBUG_BUILD} ]; then
            echo DEBUG build - skipping startup firmware checks
        else
            echo Scheduling startup firmware checks
            /etm/bin/etm-update-startup.sh &
        fi

        echo "done."
        ;;
    stop|restart|reload)
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload}"
        exit 1
        ;;
esac

exit 0
