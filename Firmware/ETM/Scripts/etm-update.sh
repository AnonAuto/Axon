#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script contains common script elements used throughout the ETM
# script subsystems
#
# load our common functions, including UCI file support
# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

readonly THIS_SCRIPT="etm-update.sh"
readonly DOCK_FW_ROOT_DIR="/root/packages"

# this variable prevents us from unmounting boot (FAT) partition if it was mounted outside this script
MOUNTED_BOOT_HERE=0
# mount path of boot partition of the SD card
readonly SD_BOOT_MNT_PATH="/boot-install"

# Exit the script. Print error message also.
exit_on_err_with_msg()
{
    log_err_msg "${THIS_SCRIPT}" "$1"
    exit 1
}

remove_prev_fw() {
    local DO_NOT_DELETE="$1"  # should be new (latest downloaded) version of firmware
    # if DO_NOT_DELETE is empty (0 length) then nothing will be deleted

    # filter out all directories except ${DO_NOT_DELETE}, they are considered as an old firmware.
    # Due to the poor support for required features in the busybox's implementation of find
    # (it does not support ! - negation) we use it in combination with grep -v, where -v means select
    # non-matching lines
    local DIRS_TO_REMOVE
    DIRS_TO_REMOVE=$(/usr/bin/find ${DOCK_FW_ROOT_DIR}/* -type d -maxdepth 0 | /bin/grep -v "${DO_NOT_DELETE}")
    local DIR=""
    for DIR in ${DIRS_TO_REMOVE}; do
        log_info_msg "${THIS_SCRIPT}" "Event=DeleteOldFirmware Directory=${DIR}"
        /bin/rm -rf "${DIR}"
    done
}

check_for_update() {
    log_info_msg "${THIS_SCRIPT}" "Event=LookingForETMupdateOnline"

    # lower case 's' for authenticated mode.
    local ECOM_ADMIN_MODE=s
    if [ -z "${AGENCY}"  ]; then
        log_info_msg "${THIS_SCRIPT}" "Event=GettingFirmwareFromEDCA Reason=NotRegistered."
        ACCESS=""
        SECRET=""
        AGENCY=edca.evidence.com
        # capital 'S' for anonymous mode.
        ECOM_ADMIN_MODE=S
    fi

    local SERIAL
    SERIAL=$(cat /etc/etm-serial)
    # get the firmware that is specific for this device. E.com ignores serial number if the early_access option is provided.
    # Therefore, we provide 'release' option here and the serial number. The serial number will tell e.com what fw
    # exactly to send for the dock (it may or may not be early_access). From the dock's point of view since it only has to
    # manage 1 firmware for itself, it does not matter whether it is early_access or not.
    UPDATE_CHECK=$(echo "${SERIAL}:${ACCESS}:${SECRET}" | /etm/bin/ecom-admin "${ECOM_ADMIN_MODE}" "${AGENCY}" "${TASER_DEVICE_TYPE}" "${TASER_DEVICE_MODEL}" "release" "${VERSION}" "${SERIAL}")
    # typical reply:
    # Authentication:
    # 1.5.62.1 https://dogfoodsb.evidence.com/?class=Software&proc=Download&software_id=e289ebe3152d45d88c32e11f4a061ea8&sid=&partner ...
    # or
    # Authentication:
    # OK:Software is up-to-date

    # test for parsing
    #UPDATE_TEST_VER=2.0.131220.0112
    #UPDATE_TEST_FILE=etm-0112.tar.gz
    #UPDATE_TEST_URL=http://192.168.1.158/${UPDATE_TEST_FILE}
    #UPDATE_TEST_HASH=$(/usr/bin/sha1sum /www/pages/${UPDATE_TEST_FILE} | awk '{print $1}' | tr '[A-Z]' '[a-z]')
    #UPDATE_CHECK="authentication ${UPDATE_TEST_VER} ${UPDATE_TEST_URL} ${UPDATE_TEST_HAS}"

    # split results into positional parameters
    # junk ensures at least one
    # shellcheck disable=SC2086
    # Do not use double quotes below since UPDATE_CHECK needs to be treated as multiple items instead of 1
    set -- junk ${UPDATE_CHECK}
    # get rid of junk
    shift
    # if we used authentication, get rid of that also
    if [ "${ECOM_ADMIN_MODE}" != "S" ]; then
        shift
    fi

    NEW_VERSION=$1
    URL=$2
    local HASH
    HASH=$(echo "$3" | /usr/bin/tr '[:upper:]' '[:lower:]')

    if [ "${NEW_VERSION:0:3}" == "OK:" ]; then
        log_info_msg "${THIS_SCRIPT}" "Event=FirmwareNotUpdated Reason=DockIsUpToDate"

        # there shouldn't be this value left, but make sure.
        config_get NEW_VERSION etm new_version
        if [ "${NEW_VERSION}" ]; then
            /sbin/uci delete etm.etm.new_version
            /sbin/uci commit etm
        fi

        return 0
    fi

    if [ "${NEW_VERSION:0:3}" == "ERR" ]; then
        log_err_msg "${THIS_SCRIPT}" "Event=ErrorDuringUpdateCheck Error=${NEW_VERSION}"
        return 10
    fi

    local DEST_DIR
    DEST_DIR="${DOCK_FW_ROOT_DIR}/${NEW_VERSION}"
    log_info_msg "${THIS_SCRIPT}" "Event=Downloading NewVersion=${NEW_VERSION} URL=${URL} Hash=${HASH}"

    /bin/rm -rf "${DEST_DIR}"
    /bin/mkdir -p "${DEST_DIR}"
    local CURL_RESULT
    /usr/bin/curl --cacert "${SSL_CA_BUNDLE}" -o "${DEST_DIR}/bundle.tar.gz" "${URL}"
    CURL_RESULT="$?"

    if [ "${CURL_RESULT}" -ne 0 ]; then
        log_err_msg "${THIS_SCRIPT}" "Event=ErrorDuringDownload Data=${CURL_RESULT}"
        return 11
    fi

    local LOCAL_HASH
    LOCAL_HASH=$(/usr/bin/sha1sum "${DEST_DIR}"/bundle.tar.gz | /usr/bin/awk '{print $1}' | /usr/bin/tr '[:upper:]' '[:lower:]')

    if [ "${LOCAL_HASH}" == "${HASH}" ]; then
        log_info_msg "${THIS_SCRIPT}" "Event=HashVerified Hash=${HASH}"
        cd "${DEST_DIR}" || return 16
        /bin/tar -zxvf "${DEST_DIR}/bundle.tar.gz"
        /bin/chown -R root:root "${DEST_DIR}"

        # perform a very basic validation on this package to make sure we don't see an ETM 1.x class update
        # package.
        # Requirements for new packages are they must contain:
        #    version        - the version # of the update
        #    minversion     - the minimum version the update applies to
        #    update-etm.sh  - the script to do the update
        #
        # If any of these conditions fail, reject the update
        if [ ! -f version ]; then
            log_err_msg "${THIS_SCRIPT}" "Event=InvalidPackage Reason=MissingVersionMarker"
            return 13
        fi
        if [ ! -f minversion ]; then
            log_err_msg "${THIS_SCRIPT}" "Event=InvalidPackage Reason=MissingBaseVersionMarker"
            return 14
        fi
        if [ ! -f selfinstall-update.sh ]; then
            log_err_msg "${THIS_SCRIPT}" "Event=InvalidPackage Reason=MissingUpdateInstaller"
            return 15
        fi

        # basic checks pass, the responsibility is now on the selfinstall-update.sh script to
        # handle other cases and not brick the device.
        # stage the update for installation
        /sbin/uci set etm.etm.new_version="${NEW_VERSION}"
        /sbin/uci commit etm
        return 0
    else
        log_err_msg "${THIS_SCRIPT}" "Event=HashMisMatch Hash=${HASH} LocalHash=${LOCAL_HASH}"
        return 12
    fi
}

do_update() {

    local DIR="${DOCK_FW_ROOT_DIR}/${NEW_VERSION}"

    cd "${DIR}" || exit_on_err_with_msg "Event=DirectoryNotFound Dir=${DIR}"

    log_info_msg "${THIS_SCRIPT}" "Event=StartingSelfInstallUpdate NewVersion=${NEW_VERSION}"
    "${DIR}"/selfinstall-update.sh

    # if we get here then selfinstall-update did not cause any reboot. So, we want to do some cleanup and also
    # make sure etm and watchdog are running.

    /sbin/uci delete etm.etm.new_version
    /sbin/uci commit etm

    /etc/init.d/etm.sh start
    /etc/init.d/etm-wd.sh start

    return 0
}



safe_unmount_boot() {
    # If the boot partition was mounted in this script ONLY then unmount
    if [[ ${MOUNTED_BOOT_HERE} -eq 1 ]]; then
        if /bin/umount "${SD_BOOT_MNT_PATH}" ; then
            MOUNTED_BOOT_HERE=0
            log_info_msg "${THIS_SCRIPT}" "Event=UnmountedBootPartition"
        else
            log_err_msg "${THIS_SCRIPT}" "Event=UnableToUnmountBootPartition"
        fi
    fi
}

get_uboot_version() {
    # search the given u-boot.img file for their version number (major and minor based on year and month).
    # return value in format: YYYY.MM. 0000.00 default if nothing found or error occured.

    local VER_MAJ
    local VER_MIN
    local VERSION

    # grep from beginning of line to look for exact pattern : "U-boot YYYY.MM"
    VERSION=$(/usr/bin/strings "$1" | /bin/grep -E -m1 "^U-Boot [[:digit:]]{4}.[[:digit:]]{2}")

    if [[ $? -ne 0 ]]; then
        VERSION="0000.00"
    else
        VER_MAJ="${VERSION:7:4}"
        VER_MIN="${VERSION:12:2}"
        VERSION="${VER_MAJ}.${VER_MIN}"
    fi
    echo "${VERSION}"
}

check_uboot_is_compatible() {
    # Given a u-boot files, check if the new one is compatible with the existing firmware.
    # $1 = New uboot file name.
    local NEW_BOOT_FILE="$1"
    local NEW_VER

    NEW_VER=$(get_uboot_version "${NEW_BOOT_FILE}")

    # A new version of uboot was built for faster SOMs (1GHz). The new SOMs also require a linux kernel update at the
    # same time.
    if [[ "${NEW_VER}" == "2011.09" ]]; then
        safe_unmount_boot
        exit_on_err_with_msg "Event=UnableToRunEtmUpdate Reason=OldUbootVersion Version=${NEW_VER} File=${NEW_BOOT_FILE}"
    fi

    log_info_msg "${THIS_SCRIPT}" "Event=UbootUpdateAllowed"
}

check_kernel_is_compatible(){
    # Check that the linux kernel file being installed is compatible with the current system.
    # $1 = New linux kernel file name.
    # Comparision will be done by looking at the strings inside the new kernel file

    # the header portion of the kernel only contains 32 bytes of version information.
    readonly OLD_VER_FORMAT="3.2.0-AM335XPSP_04.06.00"
    local IS_OLD_FORMAT

    /usr/bin/strings "$1" | grep "${OLD_VER_FORMAT}" # return code 0 = True, else False
    IS_OLD_FORMAT=$?

    # if version is old format then dont allow this update. We dont want to roll back to old kernel versions
    if [[ ${IS_OLD_FORMAT} -eq 0 ]]; then
        safe_unmount_boot
        exit_on_err_with_msg "Event=UnableToRunEtmUpdate Reason=OldKernelVersion"
    fi

    log_info_msg "${THIS_SCRIPT}" "Event=KernelUpdateAllowed"
}


check_compatibility() {
    # Check if the uBoot and linux kernel from the downloaded package is compatible with this dock.
    # If the dock is currently running a newer version of uboot or uImage (kernel) then don't update if the
    # downloaded package has older version(s) and exit script.

    local DIR="${DOCK_FW_ROOT_DIR}/${NEW_VERSION}"
    cd "${DIR}" || (exit_on_err_with_msg "Event=UnableToRunCd Directory=${DIR}")

    # "Reset to Factory Settings" mechanism is used during this update/rollback and all required configuration files are saved on the boot partition
    # of the SD card, so factory reset scripts may detect and restore the configuration
    local FILE_SYSTEM_COMPONENTS="factory-uImage"
    local UBOOT_IMAGES="u-boot-factory-reset-var-som-am33.img u-boot-var-som-am33.img"
    local COMPONENT=""

    # make sure that all components are available
    for COMPONENT in ${FILE_SYSTEM_COMPONENTS} ${UBOOT_IMAGES}; do
        if [[ ! -f "${COMPONENT}" ]] ; then
            exit_on_err_with_msg "Event=UnableToUpdate Reason=MissingFile File=${COMPONENT}"
        fi
    done

    # ensure that mount point exists
    /bin/mkdir -p "${SD_BOOT_MNT_PATH}"
    if [[ ! -d "${SD_BOOT_MNT_PATH}" ]]; then
        # send "unable to create SD_BOOT_MNT_PATH directory"
        exit_on_err_with_msg "Event=UnableToUpdate Reason=CannotCreateMountFolder Location=${SD_BOOT_MNT_PATH}"
    fi

    # check if boot(FAT) partition of the SD card is already mounted
    if ! /bin/mount 2>/dev/null | grep "${SD_BOOT_MNT_PATH}" ; then
        # boot (FAT) partition of the SD card is not mounted, so do mount it
        if ! /bin/mount /dev/mmcblk0p1 "${SD_BOOT_MNT_PATH}" ; then
            exit_on_err_with_msg "Event=UnableToUpdate Reason=CannotMountBootPartition"
        else
            log_info_msg "${THIS_SCRIPT}" "Event=BootPartitionMounted Path=${SD_BOOT_MNT_PATH}"
            MOUNTED_BOOT_HERE=1
        fi
    else
        log_info_msg "${THIS_SCRIPT}" "Event=BootPartitionAlreadyMounted Path=${SD_BOOT_MNT_PATH}"
    fi

    if [[ ! -f "${SD_BOOT_MNT_PATH}/uImage" ]]; then
        log_info_msg "${THIS_SCRIPT}" "Event=KernelFileNotFound File=${SD_BOOT_MNT_PATH}/uImage"
    fi

    # Check if the new kernel is an acceptable version. If it is not, then function will exit the script.
    check_kernel_is_compatible "factory-uImage"

    if [[ ! -f "${SD_BOOT_MNT_PATH}/u-boot.img" ]]; then
        log_info_msg "${THIS_SCRIPT}" "Event=UbootFileNotFound File=${SD_BOOT_MNT_PATH}/u-boot.img"
    fi

    # Check if the new uboot is an acceptable version. If it is not, then function will exit the script.
    check_uboot_is_compatible "u-boot-var-som-am33.img"
    check_uboot_is_compatible "u-boot-factory-reset-var-som-am33.img"

    safe_unmount_boot "${ACTION_TYPE}"
}


#
#    MAIN
#
main () {
    local RUN_COUNT
    # disable shellcheck recommendataion of using pgrep since busybox pgrep does not have count option
    # shellcheck disable=SC2009
    RUN_COUNT=$(/bin/ps -A | /bin/grep -c etm-update.sh)

    # why 2?
    # because the pipeline to compute RUN_COUNT causes extra instances to appear in ps -A.
    # no clue why, but best guess is any commands run from a script show up in ps -A with the name of the parent.
    if [ "${RUN_COUNT}" -gt 2 ]; then
        exit_on_err_with_msg "Event=ExitingEtmUpdate Reason=SoftwareUpdateAlreadyRunning"
    fi

    # having a random delay here to disperse calls to e.com from different docks
    local RANDOM_DELAY_SECONDS=$(/etm/bin/ecom-admin n 0 59)
    sleep "${RANDOM_DELAY_SECONDS}"

    config_load etm
    config_get AGENCY operation agency_domain
    config_get VERSION etm version
    config_get ACCESS operation access_key
    config_get SECRET operation secret_key

    log_info_msg "${THIS_SCRIPT}" "Event=RunningEtmUpdate Agency=${AGENCY} CurrentVersion=${VERSION}"

    # check to see if there is an updated version
    # this code does not just immediately install a pending version, because
    # there is a scenario where that new version might prevent subsequent updates,
    # so always get the latest version from the server.
    check_for_update
    CU_RESULT=$?
    if [[ ${CU_RESULT} == 0 ]]; then
        # and if so, update it.
        # need to reload config since we already committed if a new version was downloaded
        config_load etm
        config_get NEW_VERSION etm new_version
        # shellcheck disable=SC2086
        # do not use double quotes below incase the variable may be whitespace only.
        if [[ ${NEW_VERSION} ]]; then
            check_compatibility # this will exit script if update is not compatible
            do_update
            CU_RESULT=$?
            # if it gets here then fw update was not applied and the system did not reboot
            remove_prev_fw ${NEW_VERSION}
        fi
    fi

    exit ${CU_RESULT}
}

main "$@"
