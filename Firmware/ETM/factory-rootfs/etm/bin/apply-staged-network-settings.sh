#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

. /etm/bin/etm-common.sh

readonly INTERFACE_FILE="/etc/network/interfaces"

# Rotate network configuration files to apply staged wan settings.
# stage-wan-setting-changes.sh takes configuration parameters from WebUI and saves them to $INTERFACE_FILE.2
# this function rotates these configuration files, so it makes a backup copy of $INTERFACE_FILE and then it moves
# $INTERFACE_FILE.2 to INTERFACE_FILE so the new configuration becomes active.
rotate_files() {
    if [[ -f "${INTERFACE_FILE}.bak" ]]; then
        /bin/rm -f "${INTERFACE_FILE}.bak"
    fi

    /bin/mv "${INTERFACE_FILE}" "${INTERFACE_FILE}.bak"
    /bin/mv "${INTERFACE_FILE}.2" "${INTERFACE_FILE}"
    #ensure wwwrun can still read it.
    /bin/chown root:wwwrun "${INTERFACE_FILE}"
    /bin/chmod 440 "${INTERFACE_FILE}"
}

# delay slightly since there might be a web transmission in flight.
sleep 2

if [[ -f "${INTERFACE_FILE}.2" ]] ; then
    log_info_msg "apply-staged-network-settings.sh" "triggering network restart. to $(awk -f /etm/bin/queryInterfaces.awk ${INTERFACE_FILE}.2 device=${WAN_IFACE})"

    # stop networking while old configuration is active, then rotate config files to activate new configuration and start networking
    /etc/init.d/networking stop && rotate_files && sleep 2 && /etc/init.d/networking start

    # reset traffic control as well
    /etc/init.d/etm-traffic.sh start
    # WAN interface is controlled through ifplugd, so it takes some time to restart and settle the configuration;
    # for static, after link is detected, ifplugd runs the script which calls ifup to bring the interface up, it takes some time;
    # for DHCP it's the same plus ifup starts udhcpc which acquires the lease from the server and it's even more time
    # so this script does not output new network settings because catching the exact time when they are applied is tricky,
    # but there are better options:
    #    for static - /etc/network/if-up.d/02-report-ip-addr
    #    for dhcp   - /etc/udhcpc.d/50default
    # these scripts report IP addres of WAN interface once it's up and running.

    log_info_msg "apply-staged-network-settings.sh" "new network settings applied"
else
    log_err_msg "apply-staged-network-settings.sh" "${INTERFACE_FILE}.2 is not found, network settings unchanged"
fi
