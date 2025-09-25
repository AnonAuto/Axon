#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# This script updates an ETM image by installing missing packages.
# the script assumes it is run in a folder with it's firmware
# binaries and creates and backup folder here.

readonly THIS_SCRIPT="selfinstall-update.sh"

echo selfinstaller context > /root/log/selfinstall.context.txt
set >> /root/log/selfinstall.context.txt
export >> /root/log/selfinstall.context.txt

readonly BACKUP_FILES='/etc/resolv.conf
                       /etc/network/interfaces
                       /etc/udhcpd.conf
                       /etc/config/etm
                       /etc/lighttpd.user
                       /etc/lighttpd.user.digest
                       /etc/config/network
                       /etm/secret/https.cnf
                       /etm/secret/https.crt
                       /etm/secret/https.key
                       /etm/secret/secret.pem
                       /etc/snmp/snmpd.conf
                       /etc/snmp/usr/snmpd.conf'
readonly BACKUP_ARCHIVE="cfg_backup.tar.gz"

# These files will need to be copied to boot partition during firmware update
# NOTE!! If new files are added then verify the logic of check_disk_space and
# that all files will fit into boot partition.
readonly U_BOOT_FACTORY_RESET="u-boot-factory-reset-var-som-am33.img" # uboot used during the reset only
readonly U_BOOT_PROD="u-boot-var-som-am33.img" # uboot used in production mode
readonly FACTORY_UIMAGE="factory-uImage" # linux kernel
readonly FILE_SYSTEM_COMPONENTS="factory-checksum
                                 factory-rootfs.tar.gz
                                 ${FACTORY_UIMAGE}
                                 ramdisk-factory-reset.gz"
readonly UBOOT_MLO="MLO"

# these files are extra files needed in the package but will not be copied to boot partition.
CLUSTER_VERIFY_TOOL="./cluster_verifier"
OTHER_FILES="cluster_verifier"
if [[ -f /etm/bin/cluster_verifier ]]; then
    # Should refer existing cluster_verifier over the new one
    CLUSTER_VERIFY_TOOL="/etm/bin/cluster_verifier"
fi

# mount path of boot partition of the SD card
readonly SD_BOOT_MNT_PATH="/boot-install"
readonly BOOT_DEVICE="/dev/mmcblk0p1"
# this variable prevents us from unmounting boot (FAT) partition if it was mounted outside this script
MOUNTED_BOOT_HERE=0

MODE="N/A"

log_info() {
    /usr/bin/logger -s -p daemon.info -t "${THIS_SCRIPT}" "$1 Mode=${MODE}"
}

log_err() {
    /usr/bin/logger -s -p daemon.err -t "${THIS_SCRIPT}" "$1 Mode=${MODE}"
}

log_warn() {
    /usr/bin/logger -s -p daemon.warn -t "${THIS_SCRIPT}" "$1 Mode=${MODE}"
}

# Exit the script. Print error message also.
exit_on_err_with_msg()
{
    log_err "$1"
    exit 1
}

backup_config() {
    echo "Backing up configuration..."
    local BACKUP_FOLDER="cfg_backup"
    local DIR
    local I
    for I in ${BACKUP_FILES}
    do
        DIR=$(/usr/bin/dirname "${BACKUP_FOLDER}/${I}")
        /bin/mkdir -p "${DIR}"
        /bin/cp "${I}" "${DIR}"
    done

    # update the etm config file version number to reflect the new version number of the firmware update. It is done
    # here instead of the real config file in the dock in case the update fails.
    /sbin/uci -c "${BACKUP_FOLDER}/etc/config" set etm.etm.version="${NEWVERSION}" &&
    /sbin/uci -c "${BACKUP_FOLDER}/etc/config" commit etm


    if ! /bin/tar -zcvf "${BACKUP_ARCHIVE}" -C "${BACKUP_FOLDER}" . ; then
        exit_on_err_with_msg "Event=UnableToDoSelfinstall Reason=CannotCompressConfigFiles"
    fi
}

compare_version() {
    # compare each dot separated section numerically until a
    # mismatch is found
    local LEFT="$1"
    local RIGHT="$2"
    local RESULT=0
    local PART_L="${LEFT}"
    local PART_R="${RIGHT}"
    local I=1

    while [[ ! -z "${PART_L}" ]]; do
        PART_L=$(echo "${LEFT}" | /usr/bin/cut -d. -f${I})
        PART_R=$(echo "${RIGHT}" | /usr/bin/cut -d. -f${I})

        if [[ -z "${PART_L}" ]] && [[ -z "${PART_R}" ]]; then
            continue
        fi

        if [[ "${PART_L}" -gt "${PART_R}" ]]; then
            RESULT=1
            break
        elif [[ "${PART_L}" -lt "${PART_R}" ]]; then
            RESULT=-1
            break
        fi
        I=$((I+1))
    done

    echo "${RESULT}"
}

safe_mount_boot(){
    # ensure that mount point exists
    /bin/mkdir -p "${SD_BOOT_MNT_PATH}"
    if [[ ! -d "${SD_BOOT_MNT_PATH}" ]]; then
        # send "unable to create SD_BOOT_MNT_PATH directory"
        exit_on_err_with_msg "Event=UnableToDoSelfinstall Reason=CannotCreateMountFolder Location=${SD_BOOT_MNT_PATH}"
    fi

    # check if boot(FAT) partition of the SD card is already mounted
    if ! /bin/mount 2>/dev/null | grep "${SD_BOOT_MNT_PATH}" ; then
        # boot (FAT) partition of the SD card is not mounted, so do mount it
        if ! /bin/mount "${BOOT_DEVICE}" "${SD_BOOT_MNT_PATH}" ; then
            exit_on_err_with_msg "Event=UnableToDoSelfinstall Reason=CannotMountBootPartition"
        else
            log_info "Event=BootPartitionMounted Path=${SD_BOOT_MNT_PATH}"
            MOUNTED_BOOT_HERE=1
        fi
    else
        log_info "Event=BootPartitionAlreadyMounted Path=${SD_BOOT_MNT_PATH}"
    fi
}

safe_unmount_boot() {
    # If the boot partition was mounted in this script ONLY then unmount
    if [[ ${MOUNTED_BOOT_HERE} -eq 1 ]]; then
        if /bin/umount "${SD_BOOT_MNT_PATH}" ; then
            MOUNTED_BOOT_HERE=0
            log_info "Event=UnmountedBootPartition"
        else
            log_err "Event=UnableToUnmountBootPartition"
        fi
    fi
}

copy_files_w_exit_on_fail(){
    # copy files. EXIT the script if copy fails.
    # $1 = Source
    # $2 = Destination

    # NOTE: There are no double quotes around $1. This will allow multiple files to be copied to a single directory.
    # If double quotes are used then shell will treat $1 as a single file parameter.
    # shellcheck disable=SC2086
    if ! /bin/cp $1 "$2" ; then
        safe_unmount_boot
        exit_on_err_with_msg "Event=UnableToRunSelfInstall Reason=CannotCopyFile Source=$1 Dest=$2"
    fi
}

rename_file_w_exit_on_fail(){
    # rename a single file (move). EXIT the script if it fails.
    # $1 = Source
    # $2 = Destination
    if ! /bin/mv "$1" "$2" ; then
        safe_unmount_boot
        exit_on_err_with_msg "Event=UnableToRunSelfInstall Reason=CannotRenameFile From=$1 To=$2"
    fi
}

install_mlo(){
    # MLO file is necessary with u-boot.img. It needs to be renamed also for proper bootup. Same MLO file is used
    # by both the factory reset image and the production image.
    # NOTE: any change in the logic of files copied in this function may require changes to check_disk_space also

    local COUNT=0
    local SUCCESS # 0 = True, False otherwise
    local TEMP_MLO
    local FILES_TO_DELETE
    local CLUSTER_VERIFY_OUT

    while [[ ${COUNT} -lt 3 ]]; do
        TEMP_MLO="MLO${COUNT}" # NOTE: This name length must be of DOS 8.3 format length
        copy_files_w_exit_on_fail "MLO" "${SD_BOOT_MNT_PATH}/${TEMP_MLO}"
        /bin/sync
        CLUSTER_VERIFY_OUT="$(${CLUSTER_VERIFY_TOOL} "${BOOT_DEVICE}" "${TEMP_MLO}")" # check if the clusters used by this copied file is good or not
        SUCCESS=$?

        if [[ ${SUCCESS} -eq 0 ]]; then # success
            rename_file_w_exit_on_fail "${SD_BOOT_MNT_PATH}/${TEMP_MLO}" "${SD_BOOT_MNT_PATH}/MLO"
            log_info "Event=MLOFileInstalled"
            break
        else
            FILES_TO_DELETE="${FILES_TO_DELETE} ${SD_BOOT_MNT_PATH}/${TEMP_MLO}"
            log_warn "Event=MLOClusterVerificationFailed Attempt=${COUNT} ${CLUSTER_VERIFY_OUT}"
        fi
        COUNT=$((COUNT+1))
    done

    # If double quotes are used then shell will treat it as a single file parameter.
    # shellcheck disable=SC2086
    /bin/rm -f ${FILES_TO_DELETE}

    if [[ ${SUCCESS} -ne 0 ]]; then
        if [[ -x /etm/bin/etmcrash.sh ]] ; then
            /etm/bin/etmcrash.sh
        fi
        exit_on_err_with_msg "Event=UnableToRunSelfInstall Reason=MLOFileNotCopied"
    fi
}

update_reflash() {
    # do update/rollback via reflash the entire SD card.
    # NOTE!! The order in which files are copied into boot partition will influence the logic of check_disk_space.
    # If any changes are made here then make the exact same changes in check_disk_space to verify there will be enough
    # space to copy files over.

    # check existing MLO and replace it if necessary
    local MLO_INSTALL_NEEDED=1
    if [[ -f "${SD_BOOT_MNT_PATH}/MLO" ]]; then
        local MLO_BOOT_SHA
        local MLO_UPD_SHA
        MLO_BOOT_SHA="$(/usr/bin/sha1sum ${SD_BOOT_MNT_PATH}/MLO | /usr/bin/awk '{print $1;}')"
        MLO_UPD_SHA="$(/usr/bin/sha1sum MLO | /usr/bin/awk '{print $1;}')"

        if [[ "${MLO_BOOT_SHA}" = "${MLO_UPD_SHA}" ]]; then
            # MLO at /boot partition of the SD card matches MLO from this
            # update/rollback bundle, so no need to re-install it
            log_info "Event=NoMLOInstallationNeeded"
            MLO_INSTALL_NEEDED=0
        fi
    fi

    if [[ "${MLO_INSTALL_NEEDED}" -eq 1 ]]; then
        install_mlo # if this fails then script will exit
    fi

    # install the file system components on the boot partition of the SD card;
    copy_files_w_exit_on_fail "${BACKUP_ARCHIVE}" "${SD_BOOT_MNT_PATH}"
    copy_files_w_exit_on_fail "${FILE_SYSTEM_COMPONENTS}" "${SD_BOOT_MNT_PATH}"

    # check existing factory u-boot and replace it if necessary
    local FACTORY_UBOOT_INSTALL_NEEDED=1
    if [[ -f "${SD_BOOT_MNT_PATH}/${U_BOOT_FACTORY_RESET}" ]]; then
        local FACTORY_UBOOT_BOOT_SHA
        local FACTORY_UBOOT_UPD_SHA
        FACTORY_UBOOT_BOOT_SHA="$(/usr/bin/sha1sum ${SD_BOOT_MNT_PATH}/${U_BOOT_FACTORY_RESET} | /usr/bin/awk '{print $1;}')"
        FACTORY_UBOOT_UPD_SHA="$(/usr/bin/sha1sum ${U_BOOT_FACTORY_RESET} | /usr/bin/awk '{print $1;}')"

        if [[ "${FACTORY_UBOOT_BOOT_SHA}" = "${FACTORY_UBOOT_UPD_SHA}" ]]; then
            # Factory u-boot at /boot partition of the SD card matches factory u-boot from this
            # update/rollback bundle, so no need to re-install it
            log_info "Event=NoFactoryUbootInstallationNeeded"
            FACTORY_UBOOT_INSTALL_NEEDED=0
        fi
    fi

    if [[ "${FACTORY_UBOOT_INSTALL_NEEDED}" -eq 1 ]]; then
        copy_files_w_exit_on_fail "${U_BOOT_FACTORY_RESET}" "${SD_BOOT_MNT_PATH}"
    fi

    # check existing production u-boot and replace it if necessary
    local PROD_UBOOT_INSTALL_NEEDED=1
    if [[ -f "${SD_BOOT_MNT_PATH}/${U_BOOT_PROD}" ]]; then
        local PROD_UBOOT_BOOT_SHA
        local PROD_UBOOT_UPD_SHA
        PROD_UBOOT_BOOT_SHA="$(/usr/bin/sha1sum ${SD_BOOT_MNT_PATH}/${U_BOOT_PROD} | /usr/bin/awk '{print $1;}')"
        PROD_UBOOT_UPD_SHA="$(/usr/bin/sha1sum ${U_BOOT_PROD} | /usr/bin/awk '{print $1;}')"

        if [[ "${PROD_UBOOT_BOOT_SHA}" = "${PROD_UBOOT_UPD_SHA}" ]]; then
            # Production u-boot at /boot partition of the SD card matches production u-boot from this
            # update/rollback bundle, so no need to re-install it
            log_info "Event=NoProductionUbootInstallationNeeded"
            PROD_UBOOT_INSTALL_NEEDED=0
        fi
    fi

    if [[ "${PROD_UBOOT_INSTALL_NEEDED}" -eq 1 ]]; then
        copy_files_w_exit_on_fail "${U_BOOT_PROD}" "${SD_BOOT_MNT_PATH}"
    fi

    # replace "production mode" u-boot with the factory reset one;
    # it's critical part, failure can brick the system, so do it in three steps [copy-sync-rename] to reduce the chance of error
    copy_files_w_exit_on_fail "${SD_BOOT_MNT_PATH}/${U_BOOT_FACTORY_RESET}" "${SD_BOOT_MNT_PATH}/u-boot.img.tmp"

    local PROD_UIMAGE_KERNEL_INSTALL_NEEDED=0
    if [[ ! -f "${SD_BOOT_MNT_PATH}/uImage" ]]; then
        # if uImage is gone, copy the new one from update package to it. If the uImage exists then it will be replaced later
        # with the new one (factory-uImage) when ramdisk-factory-reset image loads up.
        PROD_UIMAGE_KERNEL_INSTALL_NEEDED=1
    else
        # uImage exists, check if we need to install new kernel right away
        # Need to do this because kernel 3.2.0 was not built with `devtmpfs` which is required by new `eudev`
        #
        # Here is the structure of uImage header, where we get the `ih_name` field to detect linux kernel version
        #     typedef struct image_header {
        #         __be32        ih_magic;   /* Image Header Magic Number    */
        #         __be32        ih_hcrc;    /* Image Header CRC Checksum    */
        #         __be32        ih_time;    /* Image Creation Timestamp     */
        #         __be32        ih_size;    /* Image Data Size              */
        #         __be32        ih_load;    /* Data     Load  Address       */
        #         __be32        ih_ep;      /* Entry Point Address          */
        #         __be32        ih_dcrc;    /* Image Data CRC Checksum      */
        #         uint8_t       ih_os;      /* Operating System             */
        #         uint8_t       ih_arch;    /* CPU architecture             */
        #         uint8_t       ih_type;    /* Image Type                   */
        #         uint8_t       ih_comp;    /* Compression Type             */
        #         uint8_t       ih_name[32];/* Image Name                   */
        #     } image_header_t;
        # https://github.com/u-boot/u-boot/blob/e8ae0fa5edd152b2b29c470b88429be4cdcd2c46/include/image.h#L185-L202
        if head -c 64 "${SD_BOOT_MNT_PATH}/uImage" | tail -c 32 | strings | grep -q "Linux-3.2.0-DOCK-"; then
            PROD_UIMAGE_KERNEL_INSTALL_NEEDED=1
            log_info "Event=UpdateOldKernel OldVersion=3.2.0"
        fi
    fi

    if [[ "${PROD_UIMAGE_KERNEL_INSTALL_NEEDED}" -eq 1 ]]; then
        copy_files_w_exit_on_fail "${SD_BOOT_MNT_PATH}/${FACTORY_UIMAGE}" "${SD_BOOT_MNT_PATH}/uImage.tmp"
        /bin/sync
        rename_file_w_exit_on_fail "${SD_BOOT_MNT_PATH}/uImage.tmp" "${SD_BOOT_MNT_PATH}/uImage"
    fi

    /bin/sync

    rename_file_w_exit_on_fail "${SD_BOOT_MNT_PATH}/u-boot.img.tmp" "${SD_BOOT_MNT_PATH}/u-boot.img"

    safe_unmount_boot

    log_info "Event=FilesSavedToBootPartition"

    # synchronize all logs and send them to E.com
    if [[ -x /etm/bin/sync-etm-log.sh ]] ; then
        /etm/bin/sync-etm-log.sh
    fi

    if [[ -x /etm/bin/etmcrash.sh ]] ; then
        /etm/bin/etmcrash.sh
    fi

    # arm doors and cross-check we are ready to take off
    log_info "Event=Rebooting"
    /bin/sync
    /bin/sleep 5
    /sbin/reboot -h -f
}


applicability_check()
{
    CURRENTVERSION="$(/usr/bin/head -n 1 /etm/bin/version)"

    if [[ -z "${CURRENTVERSION}" ]]; then
        exit_on_err_with_msg "Event=ApplicabilityCheckFailed Reason=NoCurrentVersion"
    fi

    MINVERSION="$(/usr/bin/head -n 1 minversion)"
    if [[ -z "${MINVERSION}" ]]; then
        exit_on_err_with_msg "Event=ApplicabilityCheckFailed Reason=NoMinVersion"
    fi

    NEWVERSION="$(/usr/bin/head -n 1 version)"
    if [[ -z "${NEWVERSION}" ]]; then
        exit_on_err_with_msg "Event=ApplicabilityCheckFailed Reason=NoNewVersion"
    fi

    # there are two possible modes:
    #  1. forward   - it's the default mode, means that it's forward firmware update via SD card re-flash
    #  2. rollback  - means rolling back the firmware via SD card re-flash
    MODE="forward"

    log_info "Event=EvaluatingApplicability NewVersion=${NEWVERSION} CurrentVersion=${CURRENTVERSION} MinVersion=${MINVERSION}"

    # if this version is less than min version, the update doesn't apply
    if [[ "$(compare_version "${CURRENTVERSION}" "${MINVERSION}")" -lt "0" ]]; then
        exit_on_err_with_msg "Event=UpdatePackageNotApplicable Reason=CurrentOlderThanMin CurrentVersion=${CURRENTVERSION} MinVersion=${MINVERSION}"
    fi

    # if current version is equal to the version being installed, then reject the update since version are the same.
    if [[ "$(compare_version "${CURRENTVERSION}" "${NEWVERSION}")" -eq "0" ]]; then
        exit_on_err_with_msg "Event=UpdatePackageNotApplicable Reason=CurrentSameAsNew CurrentVersion=${CURRENTVERSION} NewVersion=${NEWVERSION}"
    fi

    # if current version is greater than the version being installed, then reject
    # unless there is a back revision marker that is newer than this version
    if [[ "$(compare_version "${CURRENTVERSION}" "${NEWVERSION}")" -gt "0" ]]; then
        if [ -f backversion ]; then
            # back versions control software rollback.  If the back version file exists,
            # then it indicates the newest version which is EXEMPT from rollback.  So if the
            # existing version is less than this back revision version, then the package is applied
            # thereby, rolling the system backwards from $CURRENTVERSION to $NEWVERSION.  However, if
            # the $CURRENTVERSION is newer than back version, then this is an obsolete rollback package
            # and we ignore it.
            BACKVERSION="$(/usr/bin/head -n 1 backversion)"
            if [[ "$(compare_version "${CURRENTVERSION}" "${BACKVERSION}")" -lt "0" ]]; then
                MODE="rollback"
                log_warn "Event=FoundRollbackPackage CurrentVersion=${CURRENTVERSION} BackVersion=${BACKVERSION}"
            else
                exit_on_err_with_msg "Event=UpdatePackageNotApplicable Reason=ObsoleteRollback CurrentVersion=${CURRENTVERSION} Backrevision=${BACKVERSION}"
            fi
        else
            exit_on_err_with_msg "Event=UpdatePackageNotApplicable Reason=CurrentVersionNewer CurrentVersion=${CURRENTVERSION} NewVersion=${NEWVERSION}"
        fi
    fi

    log_warn "Event=UpdateModeSet"
}


do_clean_up(){
    # before backing up configuration files, clear values for cached firmware - since it won't be there after the reflash;
    # also update firmware version
    /sbin/uci delete etm.etm.new_version

    # if one of these do not exist in the config file then its fine
    local DEVICE_TYPE_MODEL_LIST='taser_axon__taser_axon_lxcie
                                     taser_axon__taser_body_cam
                                     taser_axon__taser_body_cam_2
                                     taser_axon__taser_axon_flex_2
                                     taser_axon__taser_axon_flex_2_ctrl
                                     taser_axon__taser_fleet_cam_1
                                     taser_ecd__taser_cew_7_handle
                                     taser_ecd__taser_cew_10_handle
                                     taser_etm__taser_cew_7_dock_charger'
    local TYPES='firmware
                 early_access_firmware'

    local DEVICE_TYPE_MODEL
    for TYPE in ${TYPES}; do
        for DEVICE_TYPE_MODEL in ${DEVICE_TYPE_MODEL_LIST}; do
            /sbin/uci set "etm.${TYPE}.${DEVICE_TYPE_MODEL}=UNKNOWN"
        done
    done
    /sbin/uci commit etm

    # remove any old unnecessary files that will not be used. Only remove those files that even in the event of
    # an update failure there will not be any negative consequences.
    local FILES_TO_REMOVE='ramdisk.gz
                           u-boot-testmode-var-som-am33.img'
    local A_FILE=""

    # make sure that all components are available in the installer package
    for A_FILE in ${FILES_TO_REMOVE}; do
        /bin/rm -f "${SD_BOOT_MNT_PATH}/${A_FILE}"
    done
}

get_file_size_blocks(){
    # helper function to compute file size in blocks. Prints the total size of file if exists. Otherwise 0.
    # $1 : exact file path to compute size
    local FILE="$1"
    local FILE_SIZE=0

    if [[ -f "${FILE}" ]]; then
        FILE_SIZE="$(/bin/ls -sl "${FILE}" | /usr/bin/awk '{ print $1 }')"
    fi
    echo "${FILE_SIZE}"
}

check_disk_space(){
    # The logic of this function is heavily dependent on the the order of files copied in function update_reflash and
    # install_mlo. If there are any changes to files copied in those function, revisit the logic here also to make sure
    # disk space is calculated properly. The space calculation also depends on list of files in FILE_SYSTEM_COMPONENTS.

    local NEW_FILE_SIZE
    local OLD_FILE_SIZE
    local AVAILABLE_SPACE
    local EVENT="FwUpdateFailed"
    local REASON="NotEnoughSpaceInBoot"

    # logic of computation:
    # Compute the available space in the boot partition. Then as each file is copied make sure that there will
    # enough space to copy the files over.

    AVAILABLE_SPACE="$(/bin/df -k ${BOOT_DEVICE} | /usr/bin/awk '{ total += $4 }; END { print total }')" # in blocks

    # 1. 1st copy MLO. Maximum of up to 3 times into 3 temporary files (see install_mlo for details)
    NEW_FILE_SIZE="$(get_file_size_blocks ${UBOOT_MLO})"
    NEW_FILE_SIZE=$((NEW_FILE_SIZE * 3 ))
    if [[ "${AVAILABLE_SPACE}" -lt "${NEW_FILE_SIZE}" ]] ; then
        exit_on_err_with_msg "Event=${EVENT} Reason=${REASON} File=${UBOOT_MLO}"
    fi
    OLD_FILE_SIZE="$(get_file_size_blocks ${SD_BOOT_MNT_PATH}/${UBOOT_MLO})"
    AVAILABLE_SPACE=$((AVAILABLE_SPACE - NEW_FILE_SIZE + OLD_FILE_SIZE ))

    # Next some files are copied directly to boot without creating any temporary file copies. These are:
    # Backup archive and the items in FILE_SYSTEM_COMPONENTS
    # NOTE: the order of files matter and is depended on how files are copied in update_reflash
    local FILES_TO_COPY_IN_ORDER="${BACKUP_ARCHIVE}
                                  ${FILE_SYSTEM_COMPONENTS}"

    for A_FILE in ${FILES_TO_COPY_IN_ORDER}; do
        NEW_FILE_SIZE="$(get_file_size_blocks "${A_FILE}")"
        if [[ "$AVAILABLE_SPACE" -lt "$NEW_FILE_SIZE" ]] ; then
            exit_on_err_with_msg "Event=${EVENT} Reason=${REASON} File=${A_FILE} Required=${NEW_FILE_SIZE} Available=${AVAILABLE_SPACE}"
        fi
        OLD_FILE_SIZE="$(get_file_size_blocks "${SD_BOOT_MNT_PATH}/${A_FILE}")"
        AVAILABLE_SPACE=$((AVAILABLE_SPACE - NEW_FILE_SIZE + OLD_FILE_SIZE))
    done

    # NOTE: the order of files matter and is depended on how files are copied in update_reflash
    # Next files are copied directly into a temporary file in boot. This means old copy of a file will not be deleted.
    # These are: U_BOOT_FACTORY_RESET and  FACTORY_UIMAGE.
    FILES_TO_COPY_IN_ORDER="${U_BOOT_FACTORY_RESET}
                            ${FACTORY_UIMAGE}"

    for A_FILE in ${FILES_TO_COPY_IN_ORDER}; do
        NEW_FILE_SIZE="$(get_file_size_blocks "${A_FILE}")"
        if [[ "${AVAILABLE_SPACE}" -lt "${NEW_FILE_SIZE}" ]] ; then
            exit_on_err_with_msg "Event=${EVENT} Reason=${REASON} Data=TempFileCopy File=${A_FILE} Required=${NEW_FILE_SIZE} Available=${AVAILABLE_SPACE}"
        fi
        AVAILABLE_SPACE=$((AVAILABLE_SPACE - NEW_FILE_SIZE))
    done

    log_info "Event=DiskSpaceCheckPassed"
}

check_all_components_available(){
    local COMPONENT=""

    # make sure that all components are available in the installer package
    for COMPONENT in ${FILE_SYSTEM_COMPONENTS} ${UBOOT_MLO} ${OTHER_FILES}; do
        if [[ ! -f "${COMPONENT}" ]] ; then
            exit_on_err_with_msg "Event=UnableToDoSelfinstall Reason=MissingFile File=${COMPONENT}"
        fi
    done
}

#
#    MAIN
#
main(){
    # check whether this package is applicable to install in this system. If applicable then it will set the MODE
    # variable. If not applicable then this script will exit also.
    applicability_check

    check_all_components_available

    # since we will be going into the boot partition many times, mount it once and use it later. If unable to mount
    # the partition then exit script here.
    safe_mount_boot

    do_clean_up # of config files and in the boot partition

    backup_config # save current configuration files locally first

    # finally check if boot partition will have space for all files that will be copied, including any duplicates, and
    # backup files created earlier. if not enough space, fail and exit script.
    check_disk_space

    /etc/init.d/etm.sh stop
    /etc/init.d/etm-wd.sh stop

    log_info "Event=StartingFwChange FromVersion=${CURRENTVERSION} ToVersion=${NEWVERSION}"
    update_reflash

    # both forward and backward reflash will reboot the system if successfully updated. Therefore no need to
    # start etmd and wd processess. However, if the update fails the script exits with non-zero code. The caller
    # will need to turn on any necessary processess.
}

main "$@"
