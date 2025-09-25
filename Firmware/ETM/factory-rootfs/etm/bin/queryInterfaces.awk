#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# query the settings for a particular interface 
# from /etc/network/interfaces.
# format output as expected by the ETM web UI expects.
#

function usage() {
        print "awk -f queryInterfaces.awk <interfaces file> device=<eth device> [arg=debug]\n"
}
 
BEGIN { start = 0;
 
    if (ARGC < 3 || ARGC > 4) {
        usage();
        exit 1;
    }
 
    for (i = 2; i < ARGC; i++) {
        split(ARGV[i], pair, "=");
        if (pair[1] == "device")
            device = pair[2];
        else if (pair[1] == "arg" && pair[2] == "debug")
            debug = 1;
        else {
            usage();
            exit 1;
        }
    }
}

{
    # Look for iface line and if the interface comes with the device name
    # scan whether it is dhcp or static
    # e.g. iface eth1 inet static
    
    if ($1 == "iface")  {
 
        # Ethernet name matches - switch the line scanning on
        if ($2 == device) {
 
            if (debug)
                print $0;
 
            # It's a DHCP interface, if defined any static properties
            # change it to static
            if (match($0, / dhcp/)) {
                definedDhcp=1;
                print "proto dhcp"
            }
 
            # It's a static network interface
            else if (match ($0, / static/)) {
                definedStatic=1;
                print "proto static"
            }
 
        }
        # If it is other inteface line, switch it off
        else {
            definedStatic = 0;
            definedDhcp = 0;
        }

        next;
    }
 
    # Reaches here - means non iface lines
    # Change the static content
    if (definedDhcp) {
 
        # Already defined DHCP
        # omit everything until the iface section is
        # finished
        next;
    }
 
    # If already defined dhcp, then dump the network properties
    if (definedStatic) {

        if (debug)
            print "static - ", $0, $1;

        if ($1 == "address")
            print "ipaddr", $2;
        else if ($1 == "netmask")
            print "netmask", $2;
        else if ($1 == "gateway")
            print "gateway", $2;
        else if ($1 == "dns-nameservers")
            print "dns", $2, $3
    }
}
 
END {
}
