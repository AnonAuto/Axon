#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

# This script is executed by rcS during boot and it creates all required directories and symbolic links,
# it must run before populate-volatiles.sh script.
# populate-volatiles.sh doesn't work well when updating from 2.0.140220.0106 to any recent version with
# reduced SD card I/O. The reason is that in firmware without TMPFS logging, some directories inside /var
# have the same names as required symlinks (to the corresponding directories on TMPFS partition),
# so populate-volatiles.sh doesn't remove them, so the system contiues to write logs on SD card.

# import global constants and configuration
. /etm/bin/etm-common.sh

echo "Running etm-volatiles.sh (creating all required directories and symbolic links)"

# create /root directory with strict permissions 
force_create_dir "/root" "0700"

# create log directory on SD card
force_create_dir "${LOG_DIR}" "0700"

# create parent for below directories
force_create_dir "/var/volatile"

# create some TMPFS directories
force_create_dir "${TMPFS_LOG_DIR}"
force_create_dir "${TMPFS_ETM_TMP_DIR}"
force_create_dir "${TMPFS_STATE_DIR}"
force_create_dir "${TMPFS_SPOOL_DIR}"
force_create_dir "${TMPFS_SPOOL_DIR}/at"
force_create_dir "${TMPFS_SPOOL_DIR}/at/jobs" "0770"
# set sticky bit for at/jobs, so the directory will have all required permissions
/bin/chmod +t "${TMPFS_SPOOL_DIR}/at/jobs"
force_create_dir "${TMPFS_SPOOL_DIR}/at/spool" "0770"
# set sticky bit for at/spool, so the directory will have all required permissions
/bin/chmod +t "${TMPFS_SPOOL_DIR}/at/spool"
force_create_dir "${TMPFS_SPOOL_DIR}/cron"
force_create_dir "${TMPFS_SPOOL_DIR}/cron/crontabs"
force_create_dir "${TMPFS_SPOOL_DIR}/mail"

force_create_dir "${CURL_HOME}" "0700"
force_create_dir "${PROXY_DIR}" "0700"

# `0744` so lighttpd process can read this file.
/bin/touch "${TMPFS_ETM_TMP_DIR}/lighttpd-additional-config.conf"
/bin/chmod 0744 "${TMPFS_ETM_TMP_DIR}/lighttpd-additional-config.conf"

# create at/jobs/.SEQ file, it's required for batch command
/bin/touch "${TMPFS_SPOOL_DIR}/at/jobs/.SEQ"
/bin/chown root:root "${TMPFS_SPOOL_DIR}/at/jobs/.SEQ"
/bin/chmod 600 "${TMPFS_SPOOL_DIR}/at/jobs/.SEQ"

# create some symlinks
force_create_symlink "${TMPFS_LOG_DIR}" "${VAR_LOG_DIR}"
force_create_symlink "${TMPFS_ETM_TMP_DIR}" "${ETM_TMP_DIR}"
force_create_symlink "${TMPFS_STATE_DIR}" "${STATE_DIR}"
force_create_symlink "${TMPFS_SPOOL_DIR}" "${SPOOL_DIR}"