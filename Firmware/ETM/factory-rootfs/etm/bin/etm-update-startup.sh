#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script handles firmware updates at startup
#
# this is slightly different from the standard CRON 
# job as follows:
#
# at start up, this script is launched in the background by etm-prep.sh
# If the Dock is registered, then this script simply exits,
# resulting in no change to the current behavior.
# if the dock is not registered, then this script:
# a. will wait 3 minutes for the boot process to complete.
# b. trigger the standard update script to pull the default firmware update 
# from edca.evidence.com.
# c. repeat the process twice more at 5 minute intervals
# d. quits
#
# If the firmware update is not complete after 3 tries it will be handled by
# the next scheduled CRON job.
#
# TODO_IDEA:
# note that c. is retried regardless of success because we don't have a great way to determine whether success was because
# "we have the current firmware", or "we got new firmware", and I don't want to cause etm-update.sh to return a "failure"
# code in either case.  This needs more analysis, but for now this is an expedient work-around.
#

. /etm/bin/etm-common.sh

# wait 3 minutes
sleep 180

# check to see if we are registered
config_load etm
config_get AGENCY operation agency_domain

# exit if the dock is registered
if [ ! -z $AGENCY ]; then
    exit 0
fi

# not registered, trigger the update three times
for i in 1 2 3
do
    log_info_msg "etm-update-startup.sh" "triggering startup firmware check"
    /etm/bin/etm-update.sh now
    if [ $? -ne 0 ]; then
        # try again in 5 minutes
        log_err_msg "etm-update-startup.sh" "startup firmware check failed"
        sleep 30
    else
        log_err_msg "etm-update-startup.sh" "startup firmware check complete"
        exit 0
    fi
done

