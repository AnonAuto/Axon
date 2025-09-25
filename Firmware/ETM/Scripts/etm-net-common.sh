#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script contains common script elements used throughout the ETM
# script subsystems.  This particular subset is of interest to various low
# level functions used by the networking scripts (and therefore included in
# all filesystem variants).
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !
# ! DO NOT SOURCE ANY OTHER EXTERNAL SCRIPTS, THE SCRIPT MUST BE
# ! SELF SUFFICIENT, WITHOUT ANY EXTERNAL DEPENDENCIES.
# ! BEFORE ADDING ANYTHING NEW (OR MAKING ANY MODIFICATIONS) TO THE SCRIPT
# ! MAKE SURE THAT COMMANDS OR ANY OTHER RESOURCES ARE AVAILABLE IN ALL IMAGES
# ! (i.e. TDMA ramdisk).
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#

LAN_IFACE=eth0
WAN_IFACE=eth1

# logging helpers.  These are private in many of the scripts, with
# similar names, hence these have the _msg suffix in the name, 
# but we should clean that up at some point.

log_info_msg() {
    # $1 = name of logging utility
    # $2 = message
    echo logger -s -p daemon.info -t $1 "$2"
    logger -s -p daemon.info -t $1 "$2"
}

log_info_msg_no_echo() {
    # $1 = name of logging utility
    # $2 = message
    logger -s -p daemon.info -t "$1" "$2"
}

log_err_msg() {
    # $1 = name of logging utility
    # $2 = message
    echo logger -s -p daemon.err -t $1 "$2"
    logger -s -p daemon.err -t $1 "$2"
}

log_err_msg_no_echo() {
    # $1 = name of logging utility
    # $2 = message
    logger -s -p daemon.err -t "$1" "$2"
}

log_verbose() {
    # This function logs info message if LOG_VERBOSE=1.
    # $1 = name of logging utility
    # $2 = message
    if [[ "${LOG_VERBOSE}" == "1" ]] ; then
        log_info_msg "$1" "$2"
    fi 
}

# This function can be used:
#    * to erase current DNS configuration (if called with empty DNS_CFG parameter), so resulting
#      /var/run/resolv.conf will be empty
#    * to update DNS configuration
#
# In Linux system active DNS configuration is stored in /etc/resolv.conf. In our system /etc/resolv.conf is a
# symbolic link to a runtime DNS configuration stored on TMPFS partition in /var/run/resolv.conf.
#
# The following scripts update DNS configuration:
#     * /etc/udhcpc.d/50default (executed by udhcpc if WAN_IFACE is configured as DHCP)
#     * /etc/network/if-up.d/wan-dns (executed by ifup if interface is configured as static).
#
# Depending on WAN_IFACE configuration one of the scripts above gets executed at boot time and updates the
# runtime DNS configuration, so we're good with keeping resolv.conf on TMPFS partition.
#
# On success this function returns 0. On error, this function returns 1.
update_dns_cfg() {
    # $1 = log identifier, allows to find in the logs which script called this function, for example
    #      /etc/network/if-up.d/wan-dns uses "ifup-wan-dns".
    # $2 = whitespace delimited string with IP addresses of DNS servers, usually 1 or 2, i.e "10.10.10.1 8.8.8.8",
    #      first IP address will be saved first.
    local LOG_ID="$1"
    local DNS_CFG="$2"

    # symbolic link to runtime resolv.conf
    local SYMLINK_RESOLVCONF="/etc/resolv.conf"
    # if SYMLINK_RESOLVCONF is not a symbolic link but a file or a directory, the following variable will keep
    # the path where the backup copy will be saved
    local SYMLINK_RESOLVCONF_BAK="${SYMLINK_RESOLVCONF}.bak"
    # runtime resolv.conf
    local RUNTIME_RESOLVCONF="/var/run/resolv.conf"
    # temporary runtime resolv.conf, used to save new DNS configuration and the replace current runtime resolv.conf;
    # this two-step process is required to eliminate potential failures
    local RUNTIME_RESOLVCONF_TMP="${RUNTIME_RESOLVCONF}.tmp"

    # create an empty temporary RUNTIME_RESOLVCONF_TMP
    if ! echo -n "" > "${RUNTIME_RESOLVCONF_TMP}" ; then
        log_err_msg "${LOG_ID}" "Failed to create empty ${RUNTIME_RESOLVCONF_TMP}"
        # can't proceed, keeping old DNS configuration
        return 1
    fi

    # if DNS configuration is provided then save it to RUNTIME_RESOLVCONF_TMP
    if [[ ! -z "${DNS_CFG}" ]] ; then
        for DNS_IP in ${DNS_CFG} ; do
            if echo "nameserver ${DNS_IP}" >> "${RUNTIME_RESOLVCONF_TMP}" ; then
                log_info_msg "${LOG_ID}" "DNS: ${DNS_IP} is saved in ${RUNTIME_RESOLVCONF_TMP}"
            else
                log_err_msg "${LOG_ID}" "failed to save DNS: ${DNS_IP} in ${RUNTIME_RESOLVCONF_TMP}"
                # can't proceed, keeping old DNS configuration
                return 1
            fi
        done
    fi

    # check if SYMLINK_RESOLVCONF is a symbolic link pointing on RUNTIME_RESOLVCONF;
    # readlink will return an empty string if symbolic link does not exist or if it's a file or directory
    if [[ "$(readlink ${SYMLINK_RESOLVCONF})" != "${RUNTIME_RESOLVCONF}" ]] ; then
        # SYMLINK_RESOLVCONF link exists and points to a wrong place OR SYMLINK_RESOLVCONF is a file or directory
        # OR SYMLINK_RESOLVCONF does not exist; in all cases, need to create/update the link;

        # first of all, check is there any node with SYMLINK_RESOLVCONF name
        if [[ -e "${SYMLINK_RESOLVCONF}" ]] ; then
            log_info_msg "${LOG_ID}" "found ${SYMLINK_RESOLVCONF} and it's not a symbolic link: $(ls -al ${SYMLINK_RESOLVCONF})"
            # save backup
            if ! mv "${SYMLINK_RESOLVCONF}" "${SYMLINK_RESOLVCONF_BAK}" ; then
                # it's an error, but not a critical one, so there is no need to terminate here
                log_err_msg "${LOG_ID}" "failed to save backup of ${SYMLINK_RESOLVCONF} to ${SYMLINK_RESOLVCONF_BAK}"
            else
                log_info_msg "${LOG_ID}" "backup of ${SYMLINK_RESOLVCONF} is saved to ${SYMLINK_RESOLVCONF_BAK}"
            fi
        fi

        # create/update the symbolic link
        # ln options:
        #  -s  Make symlinks instead of hardlinks
        #  -f  Remove existing destination files
        if ! ln -f -s "${RUNTIME_RESOLVCONF}" "${SYMLINK_RESOLVCONF}" ; then
            # CRITICAL ERROR
            log_err_msg "${LOG_ID}" "Failed to create ${SYMLINK_RESOLVCONF} symbolic link to ${RUNTIME_RESOLVCONF}"
            return 1
        else
            log_info_msg "${LOG_ID}" "Recreated ${SYMLINK_RESOLVCONF} symbolic link to ${RUNTIME_RESOLVCONF}"
        fi
        
    fi

    # SYMLINK_RESOLVCONF is OK and points to RUNTIME_RESOLVCONF, update runtime DNS configuration
    if ! mv "${RUNTIME_RESOLVCONF_TMP}" "${RUNTIME_RESOLVCONF}" ; then
        # CRITICAL ERROR
        log_err_msg "${LOG_ID}" "failed to replace ${RUNTIME_RESOLVCONF} with ${RUNTIME_RESOLVCONF_TMP}"
        return 1
    fi

    return 0
}

#get ip address of the interface name provided.
#optionally, log to syslog the ip address.
get_ip_address() {
    local INTERFACE="$1" #required
    local LOG_ID="$2" #optional
    
    #check for empty parameter
    if [[ -z "${INTERFACE}" ]]; then
        return
    fi

    local IP="$(ifconfig ${INTERFACE} | grep inet | awk '{print $2}' | sed  -e "s/addr://")"
    
    #only write to syslog if option is proived
    if [[ ! -z "${LOG_ID}" ]]; then
        if [[ ! -z "${IP}" ]]; then
            log_info_msg_no_echo "${LOG_ID}" "detected ${INTERFACE} IP address: ${IP}"
        else
            log_info_msg_no_echo "${LOG_ID}" "${INTERFACE} IP address not yet found."
        fi
    fi
    
    echo ${IP}
}

