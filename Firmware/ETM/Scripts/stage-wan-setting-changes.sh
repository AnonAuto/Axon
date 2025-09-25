#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

#!!!!!! IMPORTANT NOTES !!!!!!
#This script is called by lua scripts executed from the web UI.
#The last standard output before exiting from this script will be 
#parsed for "ERROR;" message to determine if there was any errors. 
#That message will be send back to the web UI for the user to see.
#Therefore, be mindful of what you echo to standard out before
#exiting from the script. Use report_error_to_web_UI_and_exit.
#!!!!!!END IMPORTANT NOTES!!!!!

. /etm/bin/etm-common.sh
. /etm/bin/valid_ip.sh

SCRIPT_NAME="stage-wan-setting-changes"

#this function will exit the script. the error message
#will be transmitted back to the user and displayed on the web UI
#when called by LUA script.
report_error_to_web_UI_and_exit () {
    echo "ERROR: Network configuration update failed."
    exit 1
}

usage() {
cat <<USAGE
stage-wan-setting-changes.sh [dhcp|static] [ipaddr] [netmask] [gateway] [dns]
===============================================================================
Parameters:
  mode      dhcp or static.  If static the remaining parameters are required.
            if dhcp, then additional parameters are an error.
  ipaddr    dotted ip4 address for the local static ipaddress
  netmask   dotted ip4 address for the local subnet.  (NOT compact form)
  gateway   dotted ip4 address for upstream gateway
  dns       one or two dotted ip4 DNS servers. At least one must be specified.

ERROR:$*
USAGE
log_info_msg "${SCRIPT_NAME}" "ERROR:$*"
report_error_to_web_UI_and_exit
}

readonly MODE=$1
readonly IPADDR=$2
readonly MASK=$3
readonly GATEWAY=$4
readonly DNS1=$5
readonly DNS2=$6
readonly INTERFACE_FILE="/etc/network/interfaces"

# Validate the proto.
abort_if_invalid_proto() {
    local PROTO="$1"

    # proto values are always lowercase
    if [[ "${PROTO}" != "static" ]] && [[ "${PROTO}" != "dhcp" ]] ; then
        # ${INTERFACE_FILE}.2 Possible corruption. Can't rotate file."
        # See important notes on top.
        log_info_msg "${SCRIPT_NAME}" "ERROR: Invalid WAN proto: '${PROTO}'"
        report_error_to_web_UI_and_exit 
    fi
}

# validate the ip address. The second parameter contains the key word e.g. IP Address /  Network Mask 
# to provide details about the data being passed. The third parameter is optional.
# The presence of this parameter indicates that the script is validating the IP data that was just changed.
# If the IP data is invalid then the script will log a message and abort.  
abort_if_invalid_ip() {
    local IP=$1
    local MSG=$2
    local LOG_IF_CORRUPT_FILE=$3
    if valid_ip $IP; then
        return 0
    else
        if [[ -z ${LOG_IF_CORRUPT_FILE} ]]; then
            usage Invalid $MSG $IP
        else
            # Parsing of IP data failed so exit to avoid file rotation. Possible corruption.
            # see important notes on top
            log_info_msg "${SCRIPT_NAME}" "ERROR: IP addressed could not be validated."
            report_error_to_web_UI_and_exit
        fi
    fi
}

get_interface_data() {
    local ID=$1
    # Below is the output of queryInterfaces.awk
    # root@taser-etmv2:~# awk -f /etm/bin/queryInterfaces.awk /etc/network/interfaces device=eth1
    # proto static
    # ipaddr 192.168.0.102
    # netmask 255.255.255.0
    # gateway 192.168.0.1
    # dns 192.168.0.1
    # 
    # The second awk command takes the regular expresion as variable. If the regex is "ipaddr", below command will
    # output 192.168.0.102
    #
    local IF_DATA=$(awk -f /etm/bin/queryInterfaces.awk $INTERFACE_FILE.2 device=$WAN_IFACE | awk -v pattern=$ID '$1 ~ pattern {print $2}')
    if [[ -z ${IF_DATA} ]]; then
        # Above awk command returns NULL if the interface file is unparseable, so set the return variable to INVALID so that it 
        # will be used as a valid parameter in the calling function
        IF_DATA=INVALID
    fi

    echo ${IF_DATA}
}

abort_if_invalid_file() {
    # Validate IP configuration
    local WAN_PROTO="$(get_interface_data proto)"
    abort_if_invalid_proto "${WAN_PROTO}"

    # static IP configuration require more validation steps
    if [[ "${WAN_PROTO}" == "static" ]] ; then
        local WAN_IP="$(get_interface_data ipaddr)"
        local NET_MASK="$(get_interface_data netmask)"
        local GATE_WAY="$(get_interface_data gateway)"
        # Validate the first DNS
        local DNS_1="$(get_interface_data dns)"

        abort_if_invalid_ip ${WAN_IP} "IP Address" "log-if-invalid"
        abort_if_invalid_ip ${NET_MASK} "Network Mask" "log-if-invalid"
        abort_if_invalid_ip ${GATE_WAY} "Gateway IP Address" "log-if-invalid"
        abort_if_invalid_ip ${DNS_1} "DNS 1 IP Address" "log-if-invalid"
    fi
}

# DOCK-1212: Checks the return status of changeInterfaces.awk file which is passed as a parameter to 
# this function.
abort_if_error() {
    local AWK_RETURN_STATUS=$1
    if [[ ${AWK_RETURN_STATUS} -ne 0 ]]; then
        # changeInterfaces.awk returns error.
        # see important notes on top
        log_info_msg "${SCRIPT_NAME}" "ERROR: Possible corruption in network interface file."
        report_error_to_web_UI_and_exit 
    fi
}

configure_dhcp() {
    echo change to dhcp
    awk -f /etm/bin/changeInterfaces.awk $INTERFACE_FILE device=$WAN_IFACE mode=dhcp > $INTERFACE_FILE.2
    # DOCK-1212: Static IP configuration failure can corrupt the network interfaces file
    # Check return status of awk script
    abort_if_error "$?"
    # DOCK-1212: Check the file to make sure it can be parsed so that an invalid file is never rotated into place.
    abort_if_invalid_file
}

configure_static() {
    echo change to static
    # first configure the IP addresses
    awk -f /etm/bin/changeInterfaces.awk $INTERFACE_FILE device=$WAN_IFACE mode=static address=$IPADDR gateway=$GATEWAY netmask=$MASK nameservers=$DNS1\ $DNS2 > $INTERFACE_FILE.2
    # DOCK-1212: Static IP configuration failure can corrupt the network interfaces file
    # Check return status of awk script
    abort_if_error "$?"
    # DOCK-1212: Check the file to make sure it can be parsed so that an invalid file is never rotated into place.
    abort_if_invalid_file
}


if [ $MODE == 'static' ]; then
    case "$#" in
        1 ) usage Missing ipaddr;;
        2 ) usage Missing netmask;;
        3 ) usage Missing gateway;;
        4 ) usage Missing dns;;
        5 ) # single DNS (valid)
        ;;
        6 ) # dual DNS (valid)
        abort_if_invalid_ip $DNS2 'DNS2 IP Address'
        ;;
        * ) usage Only 2 DNS addresses are allowed.
    esac
    abort_if_invalid_ip $IPADDR "IP Address"
    abort_if_invalid_ip $MASK "Network Mask"
    abort_if_invalid_ip $GATEWAY "Gateway IP Address"
    abort_if_invalid_ip $DNS1 "DNS IP Address"
    configure_static
elif [ $MODE == 'dhcp' ]; then
    case "$#" in
        1 ) # valid, continue
        ;;
        * ) usage 'DHCP specification requires only one parameter.'
        ;;
    esac
    configure_dhcp
else 
    usage "Invalid Mode specified"
fi
