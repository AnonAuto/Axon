#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
. /etm/bin/etm-common.sh

echo "Running etm-wd.sh (etm-watchdog service manager)"

DAEMON=/etm/bin/etm-watchdog.sh
NAME=etm-wd
DESC="Evidence Transfer Module watchdog daemon"
SYSLOG_TITLE="init-etm-wd"

start_etm_wd() {
    /etm/bin/etm-watchdog.sh > /dev/null 2>&1 &
}

stop_etm_wd() {
    # get PIDs of all running etm-watchdog.sh scripts; usually there is only one etm-watchdog.sh running
    # but there might be a case when some other script will try to start other instance of etm-watchdog.sh
    # and there is a moment (while 'later' etm-watchdog.sh checks for other instances) when there
    # might be two etm-watchdog.sh instaces running, that's why all instances are tracked
    local PID_LIST=$(pgrep -x etm-watchdog.sh 2>/dev/null)
    local PID=

    for PID in ${PID_LIST}; do
        echo "found running etm-watchdog.sh(${PID})"
        # send SIGTERM to etm-watchdog.sh, give it a chance to complete normally
        kill -TERM "${PID}"
        echo "SIGTERM has been sent to etm-watchdog.sh(${PID}), now waiting..."
        # wait until etm-watchdog.sh instance is stopped or 30 sec timeout occures. This timeout needs to be greater
        # than the time it takes etm-watchdog.sh to go through one iteration of the while loop.
        # please note that pwait may return 1 on timeout and 'if' is used to catch its completion status;
        # 'set -e' is used for this script, so there is no way to handle return code via $? variable as
        # shell will never get to the checking code.
        if ! pwait "${PID}" 30 ; then
            # timeout, kill it!
            echo "etm-watchdog.sh(${PID}) has ignored SIGTERM, sending SIGKILL to it and its children"
            killtree "${PID}" "KILL"
            echo "etm-watchdog.sh($PID) has been killed"
        else
            echo "etm-watchdog.sh(${PID}) has been successfully terminated"
        fi
    done
}

set -e

case "$1" in
    start)
        echo -n "starting $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "starting etm watchdog script"
	start_etm_wd
	echo "done."
	;;
    stop)
        echo -n "stopping $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "stopping etm watchdog script"
	stop_etm_wd
	echo "done."
	;;
    restart)
        echo -n "restarting $DESC: $NAME... "
 	$0 stop
	$0 start
	echo "done."
	;;
    reload)
    	echo -n "reloading $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "reloading etm watchdog script"
    	killall -HUP $(basename ${DAEMON})
	echo "done."
	;;
    *)
	echo "Usage: $0 {start|stop|restart|reload}"
	exit 1
	;;
esac

exit 0
