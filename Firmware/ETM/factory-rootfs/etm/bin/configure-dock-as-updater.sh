#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2015 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script configures the dock as updater and bay 
# type based on the parameter provided.
#

. /etm/bin/etm-common.sh

THIS_SCRIPT="$(basename $0)"

# Bay type 6-bay or single-bay
BAY_TYPE_TO_CONFIGURE=$1

# Types of bay
SINGLE_BAY="single-bay"
SIX_BAY="6-bay"

usage() {
cat <<USAGE
${THIS_SCRIPT} [single-bay|6-bay]
===================================================================================
Parameters:
  single-bay    Individual bay. Single-bay has one DVR slot and 1 controller slot.
  6-bay         6-bay type. It has 6 DVR slots and 6 controller slots. 

ERROR:$*
USAGE
log_info_msg ${THIS_SCRIPT} "ERROR:$*"
exit 1
}

# Verifies if the given bay type is valid.
abort_if_invalid_bay_type() {
    if [[ -z ${BAY_TYPE_TO_CONFIGURE} ]]; then
        usage "Missing bay type"
    fi
    if [[ "${BAY_TYPE_TO_CONFIGURE}" != "${SINGLE_BAY}" && "${BAY_TYPE_TO_CONFIGURE}" != "${SIX_BAY}" ]]; then
        usage "Invalid bay type"
    fi 
}

# Configures Dock operating mode as updater
configure_dock_as_updater() {
    config_load etm
    config_get DOCK_OP_MODE operation mode
    
    if [[ "${DOCK_OP_MODE}" != "upgrade" ]]; then
        log_info_msg ${THIS_SCRIPT} "Configuring Dock as updater..."
        /sbin/uci set etm.operation.mode="upgrade"
        /sbin/uci commit etm
    else
        log_info_msg ${THIS_SCRIPT} "Dock has already been configured as updater."
    fi
}

# Configures bay type 
configure_bay_type() {
    config_load etm
    config_get TYPE_OF_BAY etm bay_type

    if [[ "${TYPE_OF_BAY}" != "${BAY_TYPE_TO_CONFIGURE}" ]]; then
        log_info_msg ${THIS_SCRIPT} "Configuring bay type as ${BAY_TYPE_TO_CONFIGURE}"
        /sbin/uci set etm.etm.bay_type=${BAY_TYPE_TO_CONFIGURE}
        /sbin/uci commit etm
    else
        log_info_msg ${THIS_SCRIPT} "Bay type has already been configured as ${BAY_TYPE_TO_CONFIGURE}"
    fi
}

# Verifies configuration and restarts etmd
verify_configuration_and_restart() {
    config_load etm
    config_get TYPE_OF_BAY etm bay_type
    config_get DOCK_OP_MODE operation mode
    if [[ "${DOCK_OP_MODE}" = "upgrade" && "${TYPE_OF_BAY}" = "${BAY_TYPE_TO_CONFIGURE}" ]]; then
        log_info_msg ${THIS_SCRIPT} "Configuration successful!!"
        /etc/init.d/etm.sh restart
        return 0
    else
        log_info_msg ${THIS_SCRIPT} "Configuration FAILED.FAILED.FAILED. Restart ${THIS_SCRIPT} again"
        return 1
    fi
}

# main

abort_if_invalid_bay_type

# Configure Docks operating Mode
configure_dock_as_updater
# Configures bay type
configure_bay_type

verify_configuration_and_restart
CONFIG_STATUS=$? 

exit ${CONFIG_STATUS}
