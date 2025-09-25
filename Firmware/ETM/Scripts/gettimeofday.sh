#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: gettimeofday.sh
#
# This script uses adjtimex to read tv_sec (seconds passed since the Epoch)
# and tv_usec (microseconds fraction) from the system and outputs
# these values as: TV_SEC.TV_USEC
#
# call adjtimex and save its output into a variable
# Sample output:
#  root@taser-etmv2:~# adjtimex 
#      mode:         0
#  -o  offset:       0
#  -f  frequency:    0
#      maxerror:     16000000
#      esterror:     16000000
#      status:       64 (UNSYNC)
#  -p  timeconstant: 2
#      precision:    1
#      tolerance:    32768000
#  -t  tick:         10000
#      time.tv_sec:  1452292941
#      time.tv_usec: 317591
#      return value: 5 (clock not synchronized)
#

. /etm/bin/etm-common.sh

SCRIPT_NAME="gettimeofday.sh"

ADJTIMEX_OUTPUT="$(/sbin/adjtimex)"

# extract TV_SEC part
# grep:
#   ^            - beginning of the line
#   [ ]*         - any number of spaces
#   time.tv_sec: - our target text string
#   [0-9]*       - any number of digits
#   $            - end of the line
#
# sed:
#   -r           - use extended regex syntax
#   s/           - replace the matching pattern (after /)
#   [ ]*         - any number of spaces
#   time.tv_sec: - our target text string
#   //g          - replacement is between // (in our case - nothing)
#
# grep finds time.tv_sec: line and following sed removes everything except value
TV_SEC="$(echo "${ADJTIMEX_OUTPUT}" | /bin/grep -E "^[ ]*time.tv_sec:[ ]*[0-9]*$" | /bin/sed -r "s/[ ]*time.tv_sec:[ ]*//g")"
# extract TV_USEC part
# grep finds time.tv_usec: line and following sed removes everything except value
TV_USEC="$(echo "${ADJTIMEX_OUTPUT}" | /bin/grep -E "^[ ]*time.tv_usec:[ ]*[0-9]*$" | /bin/sed -r "s/[ ]*time.tv_usec:[ ]*//g")"
# normalize TV_USEC, so it's always 6 symbols (required for proper sorting) 
TV_USEC="$(printf "%06d" ${TV_USEC})"

if [[ -z "${TV_SEC}" ]] || [[ -z "${TV_USEC}" ]]; then
   log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AdjtimexFailed"
   exit 1
fi

echo "${TV_SEC}.${TV_USEC}"
