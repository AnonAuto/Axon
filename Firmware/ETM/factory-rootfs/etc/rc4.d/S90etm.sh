#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
. /etm/bin/etm-common.sh

echo "Running etm.sh"

DAEMON=${ETMD}
NAME=etmd
DESC="Evidence Transfer Module Transfer daemon"

start_etm() {

    # update version information in config file for access by LUA scripts, etc.
    /sbin/uci set etm.etm.version=$ETM_VERSION
    /sbin/uci set etm.etm.buildinfo="$ETM_BUILDINFO"
    /sbin/uci commit etm
    logger -s -p daemon.info -t "init-etm" "ETM firmware: $ETM_VERSION"
    
    # rebuild the crontab file
    logger -s -p daemon.info -t "init-etm" "building crontab"
    /etm/bin/build-crontab.sh

    # clear any camera mounts
    /etm/bin/unmount-camera-devices.sh

    # initialize our status tracking files
    logger -s -p daemon.info -t "init-etm" "initializing status"
    /etm/bin/etmstat.sh > /dev/null
    
    # OBSOLETE: ?
    #  # hotplug causes problems, we shut it down, and create nodes manually
    #   killall hotplug2
    #   init_dev
    
        # busybox init is messed up, the HOME directoy is not set at this point during boot. So we manually set so GPG can find the key chain
        #export HOME=/root
    
        # check for software update
    #   /etm/bin/swupdate now

    # trigger LED notification on SOM board:
    /etm/bin/led-ctrl green

    #start ETM
    logger -s -p daemon.info -t "init-etm" "starting etmd"
    ${DAEMON} >/dev/console 2>/dev/console &
    # give etmd some time to take off; usually it takes ~250 ms to get to the place where etmd installs signal handlers for POSIX signals;
    # without this delay etmd may (and probably will) terminate right after start if sync-etm-log.sh will send him a SIGUSR1 for log rotation;
    sleep 1
    #   sleep 5
    
        #push existing devices into ETM process
    #   for dev in /sys/bus/usb/devices/*/uevent; do
    #   	[ -e "$dev" ] && echo -n add > "$dev"
    #   done  
}

stop_etm() {
    logger -s -p daemon.info -t "init-etm" "signalling shutdown to etmd"
    killall etmd
    # wait for process to actually stop, or kill it hard
    sleep 3
    # wait longer if necessary
    CNT=0
    while [[  $CNT -lt 15  &&  -e /var/run/etm.pid  ]]; do
        sleep 1
        CNT=$((CNT+1))
    done
    
    if [ -e /var/run/etm.pid ]; then
        logger -s -p daemon.info -t "init-etm" "etmd ignored shutdown, killing it"
        # if we get here, we've been stuck waiting to shutdown for 1 minute.  
        # force kill the etm processes
        killall -9 etmd
        rm /var/run/etm.pid
    fi
}

# do not enable exception handling.  This aborts if any step fails, but etmstat.sh can 
# fail and we should still start up etmd
#set -e

case "$1" in
    start)
        echo -n "starting $DESC: $NAME... "
        logger -s -p daemon.info -t "init-etm" "starting etmd daemon"
	start_etm
	echo "done."
	;;
    stop)
        echo -n "stopping $DESC: $NAME... "
        logger -s -p daemon.info -t "init-etm" "stopping etmd daemon"
	stop_etm
	echo "done."
	;;
    restart)
        echo -n "restarting $DESC: $NAME... "
        logger -s -p daemon.info -t "init-etm" "restarting etmd"
 	$0 stop
	$0 start
	echo "done."
	;;
    reload)
    	echo -n "reloading $DESC: $NAME... "
        logger -s -p daemon.info -t "init-etm" "killing etmd daemon"
    	killall -HUP $(basename ${DAEMON})
	echo "done."
	;;
    *)
	echo "Usage: $0 {start|stop|restart|reload}"
	exit 1
	;;
esac

exit 0
