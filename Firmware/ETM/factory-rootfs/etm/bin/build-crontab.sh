#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: build-crontab.sh
#
# build the cron execution table and make it active.

# load our common functions, including UCI file support
. /etm/bin/etm-common.sh

SCRIPT_NAME="build-crontab.sh"
TEMP_FILE=$ETM_TMP_DIR/.crontab-taser

# RANDOM_OFFSET_HOUR_START
ROHS=$(/etm/bin/ecom-admin n 0 23)

# Given an hour value where 0<= value <= inf, find its module of 24 (number of hours in a day)
normalize_hour (){
  echo $(((ROHS+$1)%24))
}

# reset clock every 4 hours
RTC_RANDOM_MINUTE=$(/etm/bin/ecom-admin n 0 59)
RTC_RANDOM_HOUR=$(/etm/bin/ecom-admin n 0 3)
RTC_INTERVAL="${RTC_RANDOM_MINUTE} ${RTC_RANDOM_HOUR},$(( RTC_RANDOM_HOUR + 4 )),$(( RTC_RANDOM_HOUR + 8 )),$(( RTC_RANDOM_HOUR + 12 )),$(( RTC_RANDOM_HOUR + 16 )),$(( RTC_RANDOM_HOUR + 20 )) * * *"

# logs twice every hour spread out over 30 mintues
LOG_RANDOM_NUMBER=$(/etm/bin/ecom-admin n 0 29)
LOG_UPLOAD_INTERVAL="${LOG_RANDOM_NUMBER},$((LOG_RANDOM_NUMBER + 30)) * * * *"

# Password swap every 6 hours, just before firmware update
PASSWORD_RESET_MINUTE=$((LOG_RANDOM_NUMBER + 5))
PASSWORD_RESET_INTERVAL="${PASSWORD_RESET_MINUTE} $(normalize_hour  1),$(normalize_hour  7),$(normalize_hour  13),$(normalize_hour  19) * * *"

# Firmware updates every 6 hours, starting at 2am block hour. Place a gap from the log upload interval start time.
# This means FW update interval can happen anywhere from 10 min to 50 minute of the hour block. 40 min window.
# Also it will not run while log upload is running.
FW_RANDOM_NUMBER=$(/etm/bin/ecom-admin n $((LOG_RANDOM_NUMBER + 10)) $((LOG_RANDOM_NUMBER + 20)))
ETM_FIRMWARE_INTERVAL="${FW_RANDOM_NUMBER} $(normalize_hour  1),$(normalize_hour  7),$(normalize_hour  13),$(normalize_hour  19) * * *"

# DVR Firmware updates on different hour blocks than Dock FW update.
DVR_FIRMWARE_INTERVAL="${FW_RANDOM_NUMBER} $(normalize_hour  2),$(normalize_hour  8),$(normalize_hour  14),$(normalize_hour  20) * * *"

# Update the settings from ECom.
UPDATE_ECOM_INTERVAL="$(/etm/bin/ecom-admin n 0 59) * * * *"

# CAUTION: This needs to be run at a time that does not overlap any other time here that might
#          start or stop the etmd service (notably firmware updates).  If the times overlap,
#          this script might try to restart the ETM in the middle of a firmware update.
TRUNCATE_ETM_LOG_INTERVAL="${FW_RANDOM_NUMBER} ${ROHS} * * *"

# do it faster for debugging
if [[ "${ETM_DEBUG_BUILD}" ]]; then
    LOG_UPLOAD_INTERVAL="${LOG_RANDOM_NUMBER} */1 * * *"
    DVR_FIRMWARE_INTERVAL="${ETM_FIRMWARE_INTERVAL}"
    ETM_FIRMWARE_INTERVAL="${FW_RANDOM_NUMBER} */2 * * *"
    RTC_INTERVAL="*/5 * * * *"
    UPDATE_ECOM_INTERVAL="* * * * *"
fi

log_info_msg ${SCRIPT_NAME} "RandomOffsetHourStart=${ROHS}"
log_info_msg ${SCRIPT_NAME} "RTCUpdateInterval=${RTC_INTERVAL}"
log_info_msg ${SCRIPT_NAME} "PasswordUpdateInterval=${PASSWORD_RESET_INTERVAL}"
log_info_msg ${SCRIPT_NAME} "LogUploadInterval=${LOG_UPLOAD_INTERVAL}"
log_info_msg ${SCRIPT_NAME} "DVRFWInterval=${DVR_FIRMWARE_INTERVAL}"
log_info_msg ${SCRIPT_NAME} "DockFWInterval=${ETM_FIRMWARE_INTERVAL}"
log_info_msg ${SCRIPT_NAME} "UpdateEcomInterval=${UPDATE_ECOM_INTERVAL}"


PASSWORD_COMMAND="/etm/bin/update-passwd.sh"

# output actual crontab file
cat > "${TEMP_FILE}" <<EOF

# Set the real time clock
${RTC_INTERVAL} /etm/bin/set-rtc.sh force

# set passwords
${PASSWORD_RESET_INTERVAL} ${PASSWORD_COMMAND}

# Reset etmd so the etmd.log is truncated
${TRUNCATE_ETM_LOG_INTERVAL} /etm/bin/truncate-etm-log.sh

# upload logs to E.COM
# Frequent uploads are useful for Splunk, but
# too frequent makes reconstruction difficult for analysis
${LOG_UPLOAD_INTERVAL} /etm/bin/etmcrash.sh > /dev/null 2>&1

# check for firmware updates to the ETM
# etm-update.sh also has a built-in pause of up to 10 minutes on top of this
${ETM_FIRMWARE_INTERVAL} /etm/bin/etm-update.sh

# check for DVR firmware updates
${DVR_FIRMWARE_INTERVAL} /etm/bin/cache-dvr-fw.sh

# check for ecom settings updates
${UPDATE_ECOM_INTERVAL} /etm/bin/update-ecom-settings.sh

EOF

/usr/bin/crontab "${TEMP_FILE}"
rm "${TEMP_FILE}"
