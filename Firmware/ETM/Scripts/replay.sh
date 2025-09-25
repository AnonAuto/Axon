#!/bin/sh
. /etc/functions.sh
  logger -s -p daemon.info -t "ecom-admin" "Log upload failed, replaying previous syslog"
  for line in $(cat /etm/syslog.temp); do
     logger -s -p daemon.info -t "etmcrash" $line
  done
    
