#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013-2022 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
. /etm/bin/etm-net-common.sh
. /etm/bin/etm-common.sh

echo "Running watchdogd.sh (Watchdog daemon manager)"

DAEMON=watchdog
NAME=watchdog
DESC="Watchdog Service daemon"
SYSLOG_TITLE="init-watchdogd"

start_watchdog() {
    /usr/sbin/watchdog > /dev/null 2>&1 &
}

kill_watchdog() {
    # get PIDs of all running watchdog daemons;
    local PID_LIST=$(pgrep -x ${DAEMON} 2>/dev/null)
    local PID=

    for PID in ${PID_LIST}; do
        echo "found running ${DAEMON}(${PID})"
        # send SIGTERM to ${DAEMON}, give it a chance to complete normally
        kill -TERM "${PID}"
        echo "SIGTERM has been sent to ${DAEMON}(${PID}), now waiting..."
        # wait until ${DAEMON} instance is stopped or 60 sec timeout occures;
        if ! pwait "${PID}" 60 ; then
            # timeout, kill it!
            echo "${DAEMON}(${PID}) has ignored SIGTERM, sending SIGKILL to it and its children"
            killtree "${PID}" "KILL"
            echo "${DAEMON}($PID) has been killed"
        else
            echo "${DAEMON}(${PID}) has been successfully terminated"
        fi
    done
}

stop_watchdog() {
    # pause watchdog without closing watchdog device
    # so that a hang will ultimately reboot
    local PID_LIST=$(pgrep -x ${DAEMON} 2>/dev/null)
    local PID=

    for PID in ${PID_LIST}; do
        echo "found running ${DAEMON}(${PID})"
        # send SIGSTOP to ${DAEMON}, give it a chance to complete normally
        kill -SIGSTOP "${PID}"
        echo "SIGSTOP has been sent to ${DAEMON}(${PID}) ..."
    done
}

continue_watchdog() {
    # continue previously paused (stopped) watchdog
    local PID_LIST=$(pgrep -x ${DAEMON} 2>/dev/null)
    local PID=

    for PID in ${PID_LIST}; do
        echo "found running ${DAEMON}(${PID})"
        # send SIGCONT to ${DAEMON}
        kill -SIGCONT "${PID}"
        echo "SIGCONT has been sent to ${DAEMON}(${PID}) ..."
    done
}

set -e

case "$1" in
    start)
        echo -n "starting $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "starting ${DESC}"
        start_watchdog
        echo "done."
        ;;
    stop)
        echo -n "stopping $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "stopping ${DESC}"
        stop_watchdog
        echo "done."
        ;;
    kill)
        echo -n "killing $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "killing ${DESC}"
        kill_watchdog
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
        logger -s -p daemon.info -t $SYSLOG_TITLE "reloading ${DESC}"
        killall -HUP $(basename ${DAEMON})
        echo "done."
        ;;
    continue)
        echo -n "continuing $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "continuing ${DESC}"
        continue_watchdog
        echo "done."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|kill|continue}"
        exit 1
        ;;
esac

exit 0
