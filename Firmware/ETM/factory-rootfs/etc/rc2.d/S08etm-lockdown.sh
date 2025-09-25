#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

SCRIPT_NAME="etm-lockdown.sh"

setperm() {
    DIRNAME=$1
    OPERATION=$2
    FILENAME=$3
    DEPTH=$4
    if [ -z $DEPTH ]; then
        DEPTH=1
    fi

    /usr/bin/find ${DIRNAME} -maxdepth ${DEPTH} -type f -name "${FILENAME}" | /usr/bin/xargs /bin/chmod ${OPERATION}
}

cd /
/bin/chmod og-rx dev etc etm media proc sbin sys var

# Initially dock's filesystem does not have Settings directory. It gets created
# by Qt at first run of Qt application though needed the following check to
# prevent 'chmod: Settings: No such file or directory' error at boot
if [[ -d "/Settings" ]] ; then
    /bin/chmod og-rx /Settings
fi

# remove default write flags
setperm /lib a-w '*'
setperm /bin a-w '*'
setperm /sbin a-w '*'
setperm /usr/sbin a-w '*'
setperm /usr/bin a-w '*'
setperm /usr/lib a-w '*'

cd /etc
setperm /etc og-rx '*' 4
/bin/chmod og-rx dbus-1 udev rc0.d rc1.d rc2.d rc3.d rc4.d rc5.d rc6.d rcS.d
/bin/chmod og-rx config init.d libnl default watchdog.d network
/bin/chmod og-rx udhcpc.d ssl ifplugd skel dropbear

cd /lib
/bin/chown -R root:root *
setperm /lib og-rx '*'
/bin/chmod og-rx udev config modules
# give back dropbear libs
/bin/chmod og+rx libutil-2.31.so
/bin/chmod og+rx libc-2.31.so
/bin/chmod og+rx libresolv-2.31.so
/bin/chmod og+rx libgcc_s.so.1 
/bin/chmod og+rx ld-2.31.so

setperm /bin og-rx '*'

cd /usr
setperm /usr/bin og-rx '*'
setperm /usr/sbin og-rx '*'

/bin/chmod og-rx share sbin lib libexec

cd /usr/lib
/bin/chown -R root:root *
setperm /usr/lib og-rx '*'

# ensure busybox and su have necessary perms
/bin/chmod og+rx /bin/busybox.nosuid
/bin/chmod og+rx /bin/busybox.suid
/bin/chmod og+rx /bin/su.shadow
/bin/chmod og+rx /
/bin/chmod og+rx /home

#
# Check that if 'accept_only_https' option is set in /etc/config/etm then
# lighttpd's configuration matches /etc/lighttpd.conf.master.sslonly;
# if the option is not set then lighttpd's configuration must match
# /etc/lighttpd.conf.master.nossl.
#
LIGHTTPD_CONF_MASTER_NOSSL="/etc/lighttpd.conf.master.nossl"
LIGHTTPD_CONF_MASTER_SSLONLY="/etc/lighttpd.conf.master.sslonly"
LIGHTTPD_CONF="/etc/lighttpd.conf"

replace_lighttpd_conf_if_different() {
    # compare current /etc/lighttpd.conf with ${CONF_MASTER} and if there are differences
    # then /etc/lighttpd.conf will be replaced by ${CONF_MASTER}
    local CONF_MASTER="$1"
    # -s means 'silent', cmp will return 0 (success) if two files are equal and 1 (failure) otherwise 
    if ! /usr/bin/cmp -s "${LIGHTTPD_CONF}" "${CONF_MASTER}" ; then
       # current lighttpd's config does not match with master, so replace current config
       if /bin/cp "${CONF_MASTER}" "${LIGHTTPD_CONF}" ; then
           echo "${SCRIPT_NAME}" "Event=LighttpdConfReplaced Master=${CONF_MASTER}"
       else
           echo "${SCRIPT_NAME}" "Event=LighttpdConfReplaceFailed Master=${CONF_MASTER}"
       fi
    fi
}

if [[ -f "${LIGHTTPD_CONF_MASTER_NOSSL}" ]] && [[ -f "${LIGHTTPD_CONF_MASTER_SSLONLY}" ]] ; then
    # both lighttpd's configuration master files exist, check current status of 'accept_only_https' option
    UCI_ACCEPT_ONLY_HTTPS="$(/sbin/uci get etm.etm.accept_only_https 2>/dev/null)"
    if [[ "${UCI_ACCEPT_ONLY_HTTPS}" == "1" ]] ; then
        # 'accept_only_https' option is set
        # ensuring that lighttpd's configuration is *.sslonly
        replace_lighttpd_conf_if_different "${LIGHTTPD_CONF_MASTER_SSLONLY}" 
    elif [[ "${UCI_ACCEPT_ONLY_HTTPS}" == "0" ]] ; then
        # 'accept_only_https' option is not set
        # ensuring that lighttpd's configuration is *.nossl
        replace_lighttpd_conf_if_different "${LIGHTTPD_CONF_MASTER_NOSSL}"
    else
        # using *info* and not an *err* type of logging because technically this situation is not an error;
        # for example if the firmware was upgraded from the version that did not support 'accept_only_https'
        # option to a new version that supports it; during upgrade /etc/config/etm from prev version gets
        # saved and then restored on upgraded system
        echo "${SCRIPT_NAME}" "Event=MissingAcceptOnlyHttpsOption"
        # set 'accept_only_https' to 0 (off) by default
        if ! (/sbin/uci set etm.etm.accept_only_https=0 && /sbin/uci commit etm) ; then
            echo "${SCRIPT_NAME}" "Event=AcceptOnlyHttpsOptionSetFailed"
        else
            echo "${SCRIPT_NAME}" "Event=AcceptOnlyHttpsOptionSet"
            # ensuring that lighttpd's configuration is *.nossl
            replace_lighttpd_conf_if_different "${LIGHTTPD_CONF_MASTER_NOSSL}"
        fi
    fi
else
    echo "${SCRIPT_NAME}" "Event=NoLighttpdMastersFound"
fi

#
# Check that WebUI admin credentials are OK
# Ownership/permissions will be updated on the next step
#
LIGHTTPD_AUTH_FILE="/etc/lighttpd.user.digest"
LIGHTTPD_AUTH_FILE_TMP="/etc/lighttpd.user.digest.tmp"
LIGHTTPD_AUTH_FILE_BKP="/etc/lighttpd.user.digest.bkp"
USER_AUTH=""
WEBUI_CREDS_UPDATE_UCI=0

reset_webui_creds() {
    echo "${SCRIPT_NAME} Event=WebUiCredsReset"
    /etm/bin/update-webuser.sh admin admin
}

restore_webui_creds() {
    if [[ ! -f "${LIGHTTPD_AUTH_FILE_BKP}" ]] ; then
        echo "${SCRIPT_NAME} Event=WebUiCredsRestoreNoBackup"
        return 1
    fi

    if ! cp "${LIGHTTPD_AUTH_FILE_BKP}" "${LIGHTTPD_AUTH_FILE}" ; then
        echo "${SCRIPT_NAME} Event=WebUiCredsCopyBackupFailed"
        return 1
    fi

    # read user name from lighttpd.user.digest to update web admin user name in UCI
    USER_AUTH="$(/bin/cat ${LIGHTTPD_AUTH_FILE} | /usr/bin/cut -d ':' -f 1)"
    if [[ -z ${USER_AUTH} ]] ; then
        echo "${SCRIPT_NAME}" "Event=WebUiCredsBackupCorrupt"
        return 1
    fi 

    # success
    echo "${SCRIPT_NAME}" "Event=WebUiCredsRestored"
    WEBUI_CREDS_UPDATE_UCI=1
    return 0
}

if [[ ! -f "${LIGHTTPD_AUTH_FILE}" ]] || [[ -f "${LIGHTTPD_AUTH_FILE_TMP}" ]]; then
    # absence of /etc/lighttpd.user.digest indicates critical failure;
    # presence of TMP file means that /www/scripts/set-lighttpd-passwd.sh has failed;
    # in both cases try to restore from the backup
    if ! restore_webui_creds ; then
        # restore from the backup failed, critical failure, reset creds to defaults
        reset_webui_creds
    else
        /bin/rm -f "${LIGHTTPD_AUTH_FILE_TMP}"
    fi
else
    # make sure that user name from /etc/lighttpd.user.digest matches one from UCI
    USER_AUTH="$(/bin/cat ${LIGHTTPD_AUTH_FILE} | /usr/bin/cut -d ':' -f 1)"
    USER_UCI="$(/sbin/uci get etm.etm.web_admin_user)"

    if [[ -z "${USER_AUTH}" ]] ; then
        # /etc/lighttpd.user.digest is there but failed to read the user name, indicates failure
        # try to restore from the backup:
        if ! restore_webui_creds ; then
            # there is no backup file, critical failure, reset creds to defaults
            reset_webui_creds
        fi
    elif [[ "${USER_AUTH}" != "${USER_UCI}" ]] ; then
        WEBUI_CREDS_UPDATE_UCI=1
    fi
fi

if [[ ${WEBUI_CREDS_UPDATE_UCI} -eq 1 ]] ; then
    if ! (/sbin/uci set etm.etm.web_admin_user="${USER_AUTH}" && /sbin/uci commit etm) ; then
        # failed to save user name to UCI, report failure
        echo "${SCRIPT_NAME}" "Event=WebUiCredsUCIFailed"
    else
        echo "${SCRIPT_NAME}" "Event=WebUiCredsUCIUpdated"
    fi
fi

#
# Fix ownership/permissions for lighttpd/WebUI; lighttpd runs with wwwrun:wwwrun user permissions;
#

# fix ownership/permissions for internal WebUI directories and files
# recursively set ownership to root:wwwrun for all files/directories under www (including www itself)
/bin/chown -R root:wwwrun /www
# set permissions for all directories under www (including www itself)
/usr/bin/find /www -type d | /usr/bin/xargs /bin/chmod 550
# set permissions for all files under www and it's subdirectories
/usr/bin/find /www -type f | /usr/bin/xargs /bin/chmod 440
# allow to execute certain scripts
/bin/chmod +x /www/lua/uhttpd.lua
/bin/chmod +x /www/scripts/*.sh

SERVICES_DIRS="/etc"
/bin/chown root:services ${SERVICES_DIRS}
/bin/chmod 550 ${SERVICES_DIRS}

# external directories required for lighttpd/WebUI
WEBUI_DIRS="/dev \
            /etc/network \
            /etc/config \
            /etm \
            /etm/bin \
            /usr/lib \
            /var \
            /var/log"
/bin/chown root:wwwrun ${WEBUI_DIRS}
/bin/chmod 550 ${WEBUI_DIRS}

# external executables (binaries, scripts shell/lua/awk) required for lighttpd/WebUI
WEBUI_EXECS="/usr/bin/lua5.1 \
             /usr/bin/sudo \
             /etm/bin/etm-status \
             /etm/bin/queryInterfaces.awk"
# external libraries required for lighttpd/WebUI
WEBUI_LIBS="/lib/libdl-2.31.so \
            /lib/libm-2.31.so \
            /lib/libncurses.so.5.9 \
            /lib/libpthread-2.31.so \
            /lib/librt-2.31.so \
            /lib/libtinfo.so.5.9 \
            /lib/libz.so.1.2.11 \
            /usr/lib/libEComAPI.so.1.0.0 \
            /usr/lib/libQtCoreE.so.4.8.7 \
            /usr/lib/libQtNetworkE.so.4.8.7 \
            /usr/lib/libQtXmlPatternsE.so.4.8.7 \
            /usr/lib/libattr.so.1.1.2448 \
            /usr/lib/libboost_system.so.1.72.0 \
            /usr/lib/libcrypto.so.1.1 \
            /usr/lib/libglib-2.0.so.0.6200.6 \
            /usr/lib/libgthread-2.0.so.0.6200.6 \
            /usr/lib/libhistory.so.8.0 \
            /usr/lib/libpcre.so.1.2.12 \
            /usr/lib/libreadline.so.8.0 \
            /usr/lib/libssl.so.1.1 \
            /usr/lib/libstdc++.so.6.0.28 \
            /usr/lib/libubox.so.2.0.0 \
            /usr/lib/libuci.so \
            /usr/lib/lua/5.1/uci.so"

/bin/chown root:wwwrun ${WEBUI_EXECS} ${WEBUI_LIBS}
/bin/chmod 550 ${WEBUI_EXECS} ${WEBUI_LIBS}
# sudo is a special one (requires SUID)
/bin/chmod +s /usr/bin/sudo
# external files required for lighttpd/WebUI
WEBUI_FILES="${LIGHTTPD_AUTH_FILE} \
             /etc/etm-serial \
             /etc/network/interfaces \
             /etm/bin/version"
/bin/chown root:wwwrun ${WEBUI_FILES}
/bin/chmod 440 ${WEBUI_FILES}

# external directories required for snmp
SNMP_DIRS="/etc/snmp"
for dir in ${SNMP_DIRS} ; do
    if [[ -d "${dir}" ]]; then
        /bin/chown root:snmp "${dir}"
        /bin/chmod 550 "${dir}"
    fi
done
exit 0
