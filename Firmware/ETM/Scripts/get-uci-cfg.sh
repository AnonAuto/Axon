#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: get-uci-cfg.sh
#

############################ READ THIS WARNING!!!!!!!!!!!!###########
# This script reads etm UCI configuration file, prints out only values that should be sent to the web UI.
# DO NOT send all values to the web UI. Only transmit values that are essential. All data items transmitted here are
# visible to the customer/hacker/security researcher. So, instead of deleting items that should not be sent, rather
# pick each item that should be sent.

# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

SCRIPT_NAME="get-uci-cfg.sh"

# input uci config file
UCI_CFG="/etc/config/etm"

# read UCI configuration
# output (when the dock is registered) looks like:
#   etm.etm=etm
#   etm.etm.threshold=3.0
#   etm.etm.allow_status=1
#   etm.etm.send_status=5
#   etm.etm.web_admin_user=admin
#   etm.etm.auto_reg_new_devices=1
#   etm.etm.auto_claim_all_devices=0
#   etm.etm.wizard=1
#   etm.etm.require_https_time=0
#   etm.etm.accept_only_https=0
#   etm.etm.version=...
#   etm.etm.buildinfo=...
#   etm.etm.location=...
#   etm.etm.name=...
#   etm.etm.agency=...
#   etm.etm.enable_snmp=1
#   etm.etm.snmp_user=admin
#   etm.etm.snmp_auth=MD5
#   etm.etm.snmp_encrypt=NoPriv
#   etm.operation=e-com
#   etm.operation.agency=...
#   etm.operation.agency_domain=...
#   etm.operation.agency_id=...
#   etm.operation.mode=agency
#   etm.operation.access_key=...
#   etm.operation.secret_key=...
#   etm.operation.authenticated=1
#   etm.firmware=device-firmware
#   etm.firmware.taser_axon__tasper_axon_lxcie=UNKNOW
#   etm.firmware.taser_axon__taser_body_cam=UNKNOWN
UCI_CFG_OUT="$(/sbin/uci show ${UCI_CFG} 2> /dev/null)"
if [[ -z "${UCI_CFG_OUT}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=UciCfgReadFailed UciCfg='${UCI_CFG}'"
    exit 1
fi

# some lines e.g. etm.etm.location can contain spaces, so using newline as a divider
# in the following loop
IFS=$'\n'
for LINE in ${UCI_CFG_OUT} ; do
    # choose/list specific lines/items that are necessary to be transmitted to the UI. Read WARNING on top of file.
    # DO NOT send all UCI configuration values.
    # note that firmware for different device models is gobbled up under taser_axon. If some models need to be
    # blocked then that list can be expanded here. Otherwise for exact match, match upto the = sign.
    case "${LINE}" in
        etm.etm.location=*                       | \
        etm.etm.device_home=*                    | \
        etm.etm.name=*                           | \
        etm.etm.agency=*                         | \
        etm.etm.web_admin_user=*                 | \
        etm.etm.wizard=*                         | \
        etm.etm.require_https_time=*             | \
        etm.etm.accept_only_https=*              | \
        etm.etm.snmp_sec=*                       | \
        etm.etm.snmp_auth=*                      | \
        etm.etm.snmp_encrypt=*                   | \
        etm.etm.enable_snmp=*                    | \
        etm.etm.snmp_user=*                      | \
        etm.etm.version=*                        | \
        etm.etm.buildinfo=*                      | \
        etm.etm.netlimit_kbitps=*                | \
        etm.operation.agency=*                   | \
        etm.operation.agency_domain=*            | \
        etm.operation.authenticated=*            | \
        etm.proxy.enabled=*                      | \
        etm.proxy.host=*                         | \
        etm.proxy.port=*                         | \
        etm.proxy.disable_dns_check=*            | \
        etm.firmware.taser_axon__*               | \
        etm.firmware.taser_ecd__*                | \
        etm.firmware.taser_etm__*                | \
        etm.early_access_firmware.taser_ecd__*   | \
        etm.early_access_firmware.taser_etm__*   | \
        etm.early_access_firmware.taser_axon__* )
            echo "${LINE}";;

        etm.proxy.encrypted_un=* )
            PROXY_ENCRYPTED_USER="${LINE#*=}"

            # Remove `uci show` escapes
            PROXY_ENCRYPTED_USER=$(remove_uci_show_escape "${PROXY_ENCRYPTED_USER}")

            KEY=$(proxy_get_encryption_key)
            PROXY_USER=$(proxy_decrypt_data "${PROXY_ENCRYPTED_USER}" "${KEY}")

            # Add `uci show` escapes to decrypted content so `transform_configuration` can work correctly.
            PROXY_USER=$(add_uci_show_escape "${PROXY_USER}")

            echo "etm.proxy.username=${PROXY_USER}";;

        etm.proxy.encrypted_pw=* )
            PROXY_ENCRYPTED_PASS="${LINE#*=}"

            # Remove `uci show` escapes
            PROXY_ENCRYPTED_PASS=$(remove_uci_show_escape "${PROXY_ENCRYPTED_PASS}")

            KEY=$(proxy_get_encryption_key)
            PROXY_PASS=$(proxy_decrypt_data "${PROXY_ENCRYPTED_PASS}" "${KEY}")

            # Add `uci show` escapes to decrypted content so `transform_configuration` can work correctly.
            PROXY_PASS=$(add_uci_show_escape "${PROXY_PASS}")

            echo "etm.proxy.password=${PROXY_PASS}";;

    esac
done

echo "etm.etm.serial_num=$(cat /etc/etm-serial)"
