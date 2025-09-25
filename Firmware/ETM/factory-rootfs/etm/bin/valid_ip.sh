#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: PUBLIC
#
# Test an IP address for validity, not using bash extensions
#
# Credits: Inspired by Mitch Frazier @ Linux Journal.
# see http://www.linuxjournal.com/content/validating-ip-address-bash-script
#
# The implementation is substantially rewritten to work
# within ash and works around a bug in busybox's 
# implementation of grep. 
#
# NOTE:  This script expects to be SOURCED from another
#         script.  Running it directly only runs internal
#         tests.  
#
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
valid_ip() {
    local  ip=$1
    local  stat=1

    echo $ip|grep -qE ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$
    stat=$?
    if [ $stat -eq 0 ]; then
        local p1=$(echo $ip|cut -d. -f1)
        local p2=$(echo $ip|cut -d. -f2)
        local p3=$(echo $ip|cut -d. -f3)
        local p4=$(echo $ip|cut -d. -f4)
        # busybox grep can incorrectly report success on things like 192.168.0
        # so we have to check the lengths specifically since some might be blank
	if [[ ! -z $p1 && ! -z $p2 && ! -z $p3 && ! -z $p4 ]]; then
            [[ $p1 -le 255 && $p2 -le 255 && $p3 -le 255 && $p4 -le 255 ]]
            stat=$?
	else
	    stat=1        
	fi
    fi
    return $stat
}

# If run directly, execute some tests.
if [[ "$(basename $0 .sh)" == 'valid_ip' ]]; then
    ips='
        4.2.2.2
        a.b.c.d
        192.168.1.1
        0.0.0.0
        255.255.255.255
        255.255.255.256
        192.168.0.1
        192.168.0
        1234.123.123.123
        '
    for ip in $ips
    do
        if valid_ip $ip; then stat='good'; else stat='bad'; fi
        printf "%-20s: %s\n" "$ip" "$stat"
    done
fi

