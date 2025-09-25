#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script checks with E.com for the latest firmware for the DVR devices,
# then downloads it and stores in /etm/firmware. Any previous versions of
# firmware for the same device type are removed after successful download
# of a new version.

# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

readonly SCRIPT_NAME="cache-dvr-fw.sh"

# There are two types of firmware that we can get from e.com. One is the standard released version. The other is a
# early access (aka canary) version. Depending on each device, only one of them will be applied during firmware update.
readonly EARLY_ACCESS="early_access"
readonly RELEASE="release"
readonly FW_ROOT_DIR="/etm/firmware"
readonly UCI_EARLY_ACCESS_CONFIG="early_access_firmware"

# hard coded list in case config file is broken
# be sure to update the list in selfinstall-update.sh as well
readonly DEVICE_TYPE_MODEL_LIST='taser_axon__taser_axon_lxcie
                                 taser_axon__taser_body_cam
                                 taser_axon__taser_body_cam_2
                                 taser_axon__taser_axon_flex_2
                                 taser_axon__taser_axon_flex_2_ctrl
                                 taser_axon__taser_fleet_cam_1
                                 taser_ecd__taser_cew_7_handle
                                 taser_ecd__taser_cew_10_handle
                                 taser_etm__taser_cew_7_dock_charger'

validate_fw_dir() {
    # Ensure that $DIR is a directory inside /etm/firmware.
    # On success this function returns 0, otherwise 1
    local DIR="$1"

    if [[ -d "${DIR}" ]] && [[ "${DIR:0:14}" == "${FW_ROOT_DIR}/" ]] ; then
        return 0
    fi

    return 1
}

remove_prev_fw() {
    local FW_DIR="$1"            # the top directory to remove firmware from
    local NEW_VERSION="$2"       # new (latest downloaded) version of firmware. e.g 61.15.07.31

    # filter out all directories except ${NEW_VERSION}, they considered as
    # an old firmware;
    # due to the poor support for required features in the busybox's
    # implementation of find (it does not support ! - negation) we use it in
    # combination with grep -v, where -v means select non-matching lines
    local DIRS_TO_REMOVE
    DIRS_TO_REMOVE=$(/usr/bin/find "${FW_DIR}"/* -type d -maxdepth 0 | /bin/grep -v "${NEW_VERSION}")
    local DIR=""
    for DIR in ${DIRS_TO_REMOVE}; do
        if validate_fw_dir "${DIR}"; then
            log_info_msg "${SCRIPT_NAME}" "Event=DeleteOldFw Dir=${DIR}"
            /bin/rm -rf "${DIR}"
        else
            log_info_msg "${SCRIPT_NAME}" "Event=SkipFwDirDeletion Dir=${DIR}"
        fi
    done
}

check_for_update() {
    # This function returns:
    #     0 - everything is OK - already have latest firmware and no download is required OR firmware has been
    #         successfully downloaded and registered in etm config file
    #     1 - an error occurred during update check, unable to get the current version of DVR firmware and URL to
    #         download the firmware bundle
    #     2 - an error occurred during transfer, unable to download the firmware bundle from the server
    #     3 - unable to unzip the firmware bundle, it's not a zip archive or corrupt
    #     4 - hash mismatch, firmware bundle can be unzipped but has does not match with the expected value

    local IS_EARLY_ACCESS="$1"         # type of update to do: release or early_access
    local DEVICE_TYPE_MODEL="$2" # device type and model together, e.g. taser_axon__taser_axon_flex_2
    local CONFIG_VERSION="$3"    # firmware version from /etc/config/etm config
    local ECOM_ADMIN_MODE="$4"   # authentication mode:
                                 #  s - use authentication
                                 #  S - anonymous mode (no authentication)

    # parse DEVICE_TYPE_MODEL into separate values. disable double quotes warning from shellcheck
    # shellcheck disable=SC2086
    set -- junk ${DEVICE_TYPE_MODEL/__/ }
    shift # get rid of junk
    local DEVICE_TYPE="$1"
    local MODEL="$2"

    log_info_msg "${SCRIPT_NAME}" "Event=LookForUpdate"

    # always find out what the server has on tap
    local VERSION="0.0.0.0"

    if [[ "${IS_EARLY_ACCESS}" != "${EARLY_ACCESS}" ]]; then
        IS_EARLY_ACCESS="${RELEASE}"
    fi
    local UPDATE_CHECK
    UPDATE_CHECK="$(echo "X79000000:${ACCESS}:${SECRET}" | /etm/bin/ecom-admin "${ECOM_ADMIN_MODE}" "${AGENCY}" "${DEVICE_TYPE}" "${MODEL}" "${IS_EARLY_ACCESS}" "${VERSION}")"

    # here is an example of UPDATE_CHECK for the following request (anonymous):
    # /etm/bin/ecom-admin S edca.evidence.com taser_axon taser_body_cam 0.0.0.0)
    # UPDATE_CHECK = 61.15.07.31 https://edca.evidence.com/?class=Software&proc=Download&software_id=26b9d1e41af04b71b2a01dc436140f7b&sid=&partner_id=00000000000000000000000000000000 246975ff0058674ddcd8f5bf2b3d946dc05334f8
    # here is an example of error reply:
    # UPDATE_CHECK = ERR:1060/esdca.evidence.com is not a valid hostname

    # parse UPDATE_CHECK. disable double quotes warning from shellcheck
    # shellcheck disable=SC2086
    set -- junk ${UPDATE_CHECK}
    # get rid of junk
    shift

    # if we used authentication, get rid of that also
    if [[ "${ECOM_ADMIN_MODE}" != "S" ]]; then
        shift
    fi

    # check for errors
    local ECOM_REPLY="$1"
    if [[ "${ECOM_REPLY:0:3}" == "ERR" ]] ; then
        log_err_msg "${SCRIPT_NAME}" "Event=EcomAdminError Msg='$*'"
        return 1
    fi

    # in case of success the reply will contain version number of latest firmware
    local NEW_VERSION="${ECOM_REPLY}"
    local URL="$2"
    local HASH="$3"
    HASH="$(echo "${HASH}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
    local DOWNLOAD=0
    local DEST_DIR="${FW_ROOT_DIR}/${IS_EARLY_ACCESS}/${DEVICE_TYPE_MODEL}/${NEW_VERSION}"
    local LOCAL_HASH=""

    # check to see if we have this version
    if [[ ! -f "${DEST_DIR}/bundle.zip" ]]; then
        DOWNLOAD=1
    elif [[ "${CONFIG_VERSION}" != "${NEW_VERSION}" ]];  then
        log_info_msg "${SCRIPT_NAME}" "Event=LocalVersionNotRegistered Action=DownloadAgain Local=${CONFIG_VERSION} New=${NEW_VERSION}"
        # get it again because we need to register it
        DOWNLOAD=1
    else
        LOCAL_HASH="$(/usr/bin/sha1sum "${DEST_DIR}"/bundle.zip | /usr/bin/awk '{print $1}' | /usr/bin/tr '[:upper:]' '[:lower:]')"
        if [[ "${LOCAL_HASH}" != "${HASH}" ]]; then
            log_info_msg "${SCRIPT_NAME}" "Event=LocalHashMisMatch Action=DownloadAgain"
            DOWNLOAD=1
        fi
    fi

    if [[ ${DOWNLOAD} -eq 1 ]]; then
        log_info_msg "${SCRIPT_NAME}" "Event=GettingFw Version=${NEW_VERSION}"
        echo "${URL}"
        if validate_fw_dir "${DEST_DIR}"; then
            /bin/rm -rf "${DEST_DIR}"
        fi
        /bin/mkdir -p "${DEST_DIR}"
        /usr/bin/curl --cacert "${SSL_CA_BUNDLE}" -o "${DEST_DIR}/bundle.zip" "${URL}"
        local RETVAL=$?
        if [[ ${RETVAL} -ne 0 ]]; then
            log_err_msg "${SCRIPT_NAME}" "Event=FwTransferError Code=${RETVAL}"
            return 2
        fi

        # check if the downloaded file is an actual zip file, so it can be
        # unzipped [see DOCK-1539]
        if ! /usr/bin/unzip -t "${DEST_DIR}/bundle.zip" ; then
            log_err_msg "${SCRIPT_NAME}" "Event=CannotUnzipBundleFile"
            if validate_fw_dir "${DEST_DIR}"; then
                /bin/rm -rf "${DEST_DIR}"
            fi
            return 3
        fi

        LOCAL_HASH="$(/usr/bin/sha1sum "${DEST_DIR}"/bundle.zip | /usr/bin/awk '{print $1}' | /usr/bin/tr '[:upper:]' '[:lower:]')"

        if [[ "${LOCAL_HASH}" == "${HASH}" ]]; then
            log_info_msg "${SCRIPT_NAME}" "Event=HashVerified Hash=${HASH}"
            # register the firmware
            # shellcheck disable=SC2164
            cd "${DEST_DIR}"
            /usr/bin/unzip "${DEST_DIR}/bundle.zip"

            if [[ "${IS_EARLY_ACCESS}" != "${EARLY_ACCESS}" ]]; then
                IS_EARLY_ACCESS="${RELEASE}"
                /sbin/uci set "etm.firmware.${DEVICE_TYPE_MODEL}=${NEW_VERSION}"
            else
                /sbin/uci set "etm.${UCI_EARLY_ACCESS_CONFIG}.${DEVICE_TYPE_MODEL}=${NEW_VERSION}"
            fi
            /sbin/uci commit etm

            # new firmware installed and registered. so now we can remove any old firmware
            remove_prev_fw "${FW_ROOT_DIR}/${IS_EARLY_ACCESS}/${DEVICE_TYPE_MODEL}" "${NEW_VERSION}"

            return 0
        else
            log_err_msg "${SCRIPT_NAME}" "Event=HashMisMatch Downloaded=${HASH} Computed=${LOCAL_HASH}"
            return 4
        fi
    else
        log_info_msg "${SCRIPT_NAME}" "Event=DeviceUpToDate Type=${DEVICE_TYPE} Model=${MODEL}"
    fi

    return 0
}

get_firmware(){
    local FW_TYPE="$1" # type of update to do: release or early_access
    local DEVICE_TYPE_MODEL="$2"

    local VERSION
    if [[ "${FW_TYPE}" == "${EARLY_ACCESS}" ]]; then
        config_get VERSION early_access_firmware "${DEVICE_TYPE_MODEL}"
    else
        config_get VERSION firmware "${DEVICE_TYPE_MODEL}"
    fi

    log_info_msg "${SCRIPT_NAME}" "Event=FirmwareCheck Device=${DEVICE_TYPE_MODEL} UpdateType=${FW_TYPE} CurrentVersion='${VERSION}'"

    if [[ -z "${VERSION}" ]] || [[ "${VERSION}" == "UNKNOWN" ]]; then
        VERSION="0.0.0.0";
    fi

    check_for_update "${FW_TYPE}" "${DEVICE_TYPE_MODEL}" "${VERSION}" "${ECOM_ADMIN_MODE}"
}

config_uci_for_early_access(){
    # make sure that uci entry for early access devices firmware exists before. if not then create the section
    if ! /sbin/uci get "etm.${UCI_EARLY_ACCESS_CONFIG}" ; then
        # create this section
        local SECTION

        if SECTION="$(/sbin/uci add etm early-access-device-firmware)" ; then
            log_info_msg "${SCRIPT_NAME}" "Event=AddUciSection Section=early-access-device-firmware"
        else
            log_err_msg "${SCRIPT_NAME}" "Event=UciAddFail Section=${UCI_EARLY_ACCESS_CONFIG}"
        fi

        if /sbin/uci rename "etm.${SECTION}=${UCI_EARLY_ACCESS_CONFIG}" ; then
            log_info_msg "${SCRIPT_NAME}" "Event=RenamedUciSection Section=${UCI_EARLY_ACCESS_CONFIG}"
        else
            log_err_msg "${SCRIPT_NAME}" "Event=UciRenameFail Section=${UCI_EARLY_ACCESS_CONFIG}"
        fi

        local DEVICE_TYPE_MODEL
        for DEVICE_TYPE_MODEL in ${DEVICE_TYPE_MODEL_LIST}; do
            if /sbin/uci set "etm.${UCI_EARLY_ACCESS_CONFIG}.${DEVICE_TYPE_MODEL}=UNKNOWN" ; then
                log_info_msg "${SCRIPT_NAME}" "Event=SetUciConfig Config=${DEVICE_TYPE_MODEL}"
            else
                log_err_msg "${SCRIPT_NAME}" "Event=UciSetFail Config=${DEVICE_TYPE_MODEL}"
            fi
        done

        if /sbin/uci commit etm ; then
            log_info_msg "${SCRIPT_NAME}" "Event=CommitUci"
        else
            log_err_msg "${SCRIPT_NAME}" "Event=UciCommitFail"
        fi
    fi
}

main() {
    # ensure that only single instance of this script is running
    local RUN_COUNT
    # disable shellcheck recommendataion of using pgrep since busybox pgrep does not have count option
    # shellcheck disable=SC2009
    RUN_COUNT="$(/bin/ps -A | /bin/grep -c cache-dvr-fw.sh)"

    # why 2?
    # because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
    # no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
    if [[ "${RUN_COUNT}" -gt 2 ]]; then
        log_info_msg "${SCRIPT_NAME}" "Event=ScriptAlreadyRunning Action=Exiting"
        exit 2
    fi

    # having a random delay here to disperse calls to e.com from different docks
    local RANDOM_DELAY_SECONDS=$(/etm/bin/ecom-admin n 0 59)
    sleep "${RANDOM_DELAY_SECONDS}"

    config_uci_for_early_access

    local OP_MODE
    config_load etm
    config_get AGENCY operation agency_domain
    config_get ACCESS operation access_key
    config_get SECRET operation secret_key
    config_get OP_MODE operation mode
    local ECOM_ADMIN_MODE="s"

    if [[ -z "${AGENCY}" ]]; then
        log_err_msg "${SCRIPT_NAME}" "Event=ErrorDockNotRegistered"
        if [[ "${OP_MODE}" == "upgrade" ]]; then
            log_info_msg "${SCRIPT_NAME}" "Event=GettingFirmwareFromEDCA Reason=DockIsUpdater"
            ACCESS=""
            SECRET=""
            AGENCY="edca.evidence.com"
            # capital 'S' for anonymous mode.
            ECOM_ADMIN_MODE="S"
        else
            exit 1
        fi
    fi

    local DEVICE_TYPE_MODEL
    for DEVICE_TYPE_MODEL in ${DEVICE_TYPE_MODEL_LIST}; do
        get_firmware "${RELEASE}" "${DEVICE_TYPE_MODEL}"
        get_firmware "${EARLY_ACCESS}" "${DEVICE_TYPE_MODEL}"
    done
}

main "$@"
