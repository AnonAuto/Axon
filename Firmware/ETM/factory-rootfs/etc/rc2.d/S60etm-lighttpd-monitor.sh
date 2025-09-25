#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013-2022 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
. /etm/bin/etm-common.sh

DAEMON=/etm/bin/etm-lighttpd-monitord.sh
NAME=etm-lighttpd-monitor
DESC="lighttpd monitor daemon"
SYSLOG_TITLE="init-etm-lighttpd-monitor"

start_etm_lighttpd_monitor() {
    /etm/bin/etm-lighttpd-monitord.sh > /dev/null 2>&1 &
}

stop_etm_lighttpd_monitor() {
    logger -s -p daemon.info -t "init-etm" "signalling shutdown to ${DAEMON}"
    local TOPPID=$(pgrep -f etm-lighttpd-monitord.sh 2>/dev/null | head -1)
    if [ ! -z "${TOPPID}" ]; then
        pkill -TERM -P "${TOPPID}"
    fi

    if ! pwait "${TOPPID}" 30 ; then
        logger -s -p daemon.info -t "init-etm" "force kill ${DAEMON}"
        pkill -KILL -P "${TOPPID}"
    fi
}

case "$1" in
    start)
        echo -n "starting $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "starting ${DAEMON}"
        start_etm_lighttpd_monitor
        echo "done."
        ;;

    stop)
        echo -n "stopping $DESC: $NAME... "
        logger -s -p daemon.info -t $SYSLOG_TITLE "stopping ${DAEMON}"
        stop_etm_lighttpd_monitor
        echo "done."
        ;;

    restart)
        echo -n "restarting $DESC: $NAME... "
        $0 stop
        $0 start
        echo "done."
        ;;

    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
