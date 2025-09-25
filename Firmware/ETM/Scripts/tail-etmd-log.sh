#!/bin/sh
#------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Use this script for 'tailing' active etmd logs while etmd is running.
#
# Usage: tail-etmd-log.sh [OPTIONS]
#
# Options:
#     N    print last N lines

is_positive_integer() {
    # Check if $1 is a positive integer. Returns 0, if argument is a positive integer
    # and 1 if it's not.
    local ARG="$1"

    # using egrep in quite mode (-q option) to determine if the ARG matches
    # the pattern ('[0-9]+' a sequence of digits of any lenght); if it matches
    # the pattern, the egrep will return 0 and since it's a last command in the
    # pipe, it's return code will be a return code for the whole thing.
    if echo "${ARG}" | egrep -q "^[0-9]+$" ; then
        return 0
    fi

    return 1
}

print_usage() {
    echo ""
    echo "Usage: tail-etmd-log.sh [OPTIONS]"
    echo "Continuously tail current active etmd log while etmd is running."
    echo ""
    echo "Options:"
    echo "    N    print last N lines"
    echo ""
}

# handle SIGINT, SIGTERM and SIGHUP
TERMINATE_TAIL_ETMD=0

exit_handler() {
    TERMINATE_TAIL_ETMD=1
}

trap exit_handler SIGINT SIGTERM SIGHUP

# parse command line options
LINES=""
if [[ ! -z "$1" ]] && ! is_positive_integer "$1" ; then
    echo "*** tail-etmd-log.sh ERROR: invalid argument '$1'"
    print_usage
    exit 1
fi

LINES="$1"

while [[ "${TERMINATE_TAIL_ETMD}" -eq 0 ]]; do
    # tail current active etmd.log.*
    ETMD_ACTIVE_LOG=$(lsof | grep /etm/bin/etmd | grep "${TMPFS_LOG_DIR}/etmd.log." | awk '{print $3;}')
    if [[ -z "${ETMD_ACTIVE_LOG}" ]]; then
        echo "*** tail-etmd-log.sh ERROR: Can't get current active etmd log"
        sleep 1
        continue
    fi

    echo "***  tail-etmd-log.sh: tailing '${ETMD_ACTIVE_LOG}'"
    if [[ ! -z "${LINES}" ]]; then
        # apply lines parameter only once, so the first instance of tail will show
        # required number of lines and all further instances will show everything
        tail -${LINES} -f "${ETMD_ACTIVE_LOG}" &
        LINES=""
    else
        tail -f "${ETMD_ACTIVE_LOG}" &
    fi
    TAIL_PID="$!"

    # wait until etmd will switch it's logs
    while [[ "${TERMINATE_TAIL_ETMD}" -eq 0 ]]; do
        # syn-etm-log.sh will remove 'old' etmd.log.* after synchronization, using
        # this fact to restart our tail
        if [[ ! -f "${ETMD_ACTIVE_LOG}" ]]; then
            break
        fi

        sleep 1
    done

    kill -s KILL "${TAIL_PID}" 
done

echo ""
echo "***  tail-etmd-log.sh: terminated"
