#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: echo "WEB_ADMIN_AUTH" | set-lighttpd-passwd.sh
#   WEB_ADMIN_AUTH - authentication information for lighttpd to access secure pages
#                   in the following format:
#                   WEB_ADMIN_NEW_USER;WEB_ADMIN_CUR_PASSWD;WEB_ADMIN_NEW_PASSWD
#     WEB_ADMIN_NEW_USER - new username in clear text
#     WEB_ADMIN_CUR_PASSWD - current password, encoded in base64
#     WEB_ADMIN_NEW_PASSWD - new password, encoded in base64
#
# Checks that WEB_ADMIN_CUR_PASSWD is valid and then takes WEB_ADMIN_NEW_USER and WEB_ADMIN_NEW_PASSWD
# computes authentication credentials and saves them to /etc/lighttpd.user.digest

# shellcheck disable=SC1091
. /etm/bin/etm-common.sh

SCRIPT_NAME="set-lighttpd-passwd.sh"

# print out an error status message and exit
err_exit() {
    local RC="$1"
    local ID="$2"
    echo "ERR:${RC}/${ID}"
    exit "${RC}"
}

# IFS= disables interpretation of spaces, without it leading and trailing spaces will be trimmed
# -s means secure mode, so no echo output to the console
# -r means raw input - disables interpretation of backslash escapes and line-continuation in the read data
# More info: http://wiki.bash-hackers.org/commands/builtin/read
IFS= read -s -r WEB_ADMIN_AUTH
LIGHTTPD_AUTH_FILE="/etc/lighttpd.user.digest"
LIGHTTPD_AUTH_FILE_TMP="/etc/lighttpd.user.digest.tmp"
LIGHTTPD_AUTH_FILE_BKP="/etc/lighttpd.user.digest.bkp"

# make sure that only one instance of this script is running
if [[ "$(/bin/ps -A 2>/dev/null | /bin/grep -c ${SCRIPT_NAME})" -gt 2 ]]; then
    # comparing with 2 because the pipeline to compute $SCRIPT_NAME count
    # causes extra instances to appear in ps -A; no clue why, but best guess is
    # any commands run from a script show up in ps -A with the name
    # of the parent.
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AlreadyRunning"
    err_exit 1 "AlreadyRunning"
fi

if [[ -z "${WEB_ADMIN_AUTH}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminAuthEmpty"
    err_exit 1 "WebAdminAuthEmpty"
fi

# make sure that authentication information is in right format with two ';' separators
# tr -cd ';' removes all characters from WEB_ADMIN_AUTH except ;  and wc -c counts them
if [[ "$(echo "${WEB_ADMIN_AUTH}" | /usr/bin/tr -cd ';' | /usr/bin/wc -c)" -ne 2 ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminAuthIncorrect"
    err_exit 1 "WebAdminAuthIncorrect"
fi

REALM="SecureUsers"

# '%%;*' deletes longest match of ';*' pattern from the end of the string
# for example:
#   STR="1234;ABCD;EFGH"
#   SUB_STR="${STR%%;*}"
# the value of SUB_STR is "1234" because longest match of ';*' from the end
# of the string is ";ABCD;EFGH"
#
# '#*;' deletes shortest match of '*;' pattern from the beginning of the string
# so:
#   STR="${STR#*;}"
# and now the value of STR is "ABCD;EFGH" because shortest match of '*;' from
# the beginning of the string is "1234;"

WEB_ADMIN_NEW_USER="${WEB_ADMIN_AUTH%%;*}"
WEB_ADMIN_AUTH="${WEB_ADMIN_AUTH#*;}"
WEB_ADMIN_CUR_PASSWD="${WEB_ADMIN_AUTH%%;*}"
WEB_ADMIN_NEW_PASSWD="${WEB_ADMIN_AUTH#*;}"

# decode passwords from base64
WEB_ADMIN_CUR_PASSWD="$(echo "${WEB_ADMIN_CUR_PASSWD}" | /usr/bin/openssl enc -base64 -d -A 2>/dev/null)"
WEB_ADMIN_NEW_PASSWD="$(echo "${WEB_ADMIN_NEW_PASSWD}" | /usr/bin/openssl enc -base64 -d -A 2>/dev/null)"

# validate
if [[ -z "${WEB_ADMIN_NEW_USER}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminNewUserEmpty"
    err_exit 1 "WebAdminNewUserEmpty"
fi

if [[ -z "${WEB_ADMIN_CUR_PASSWD}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminCurPasswdEmpty"
    err_exit 1 "WebAdminCurPasswdEmpty"
fi

if [[ -z "${WEB_ADMIN_NEW_PASSWD}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminNewPasswdEmpty"
    err_exit 1 "WebAdminNewPasswdEmpty"
fi

# read current username and current hash from LIGHTTPD_AUTH_FILE
AUTH_CUR="$(/usr/bin/head -n 1 ${LIGHTTPD_AUTH_FILE} 2>/dev/null)"
# '##*:' deletes longest match of '*:' pattern from the beginning of the string, also
# LIGHTTPD_AUTH_FILE uses ':' as a separator
AUTH_CUR_USER="${AUTH_CUR%%:*}"
AUTH_CUR_HASH="${AUTH_CUR##*:}"

if [[ -z "${AUTH_CUR_USER}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AuthFileCurUserReadFailed"
    err_exit 1 "AuthFileCurUserReadFailed"
fi

if [[ -z "${AUTH_CUR_HASH}" ]] || [[ "${#AUTH_CUR_HASH}" != "32" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AuthFileCurHashReadFailed"
    err_exit 1 "AuthFileCurHashReadFailed"
fi

# take current password (from user input) and current username (from LIGHTTPD_AUTH_FILE),
# calculate a hash and compare it with the current hash (from LIGHTTPD_AUTH_FILE)
CALC_CUR_HASH="$(echo -n "${AUTH_CUR_USER}:${REALM}:${WEB_ADMIN_CUR_PASSWD}" | /usr/bin/md5sum 2>/dev/null | /usr/bin/cut -b -32 2>/dev/null)"

if [[ -z "${CALC_CUR_HASH}" ]] || [[ "${#CALC_CUR_HASH}" != "32" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=CalcCurHashFailed"
    err_exit 1 "CalcCurHashFailed"
fi

if [[ "${CALC_CUR_HASH}" != "${AUTH_CUR_HASH}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminCurPasswdInvalid"
    err_exit 1 "WebAdminCurPasswdInvalid"
fi

# now after all checks we can change WebUI username/password
CALC_NEW_HASH="$(echo -n "${WEB_ADMIN_NEW_USER}:${REALM}:${WEB_ADMIN_NEW_PASSWD}" | /usr/bin/md5sum 2>/dev/null | /usr/bin/cut -b -32 2>/dev/null)"

if [[ -z "${CALC_NEW_HASH}" ]] ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=CalcNewHashFailed"
    err_exit 1 "CalcNewHashFailed"
fi

if ! echo "${WEB_ADMIN_NEW_USER}:${REALM}:${CALC_NEW_HASH}" > "${LIGHTTPD_AUTH_FILE_TMP}" ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AuthFileTmpSaveFailed AuthFileTmp=${LIGHTTPD_AUTH_FILE_TMP}"
    err_exit 1 "AuthFileTmpSaveFailed"
fi

if [[ -f "${LIGHTTPD_AUTH_FILE}" ]] ; then
    if ! /bin/cp "${LIGHTTPD_AUTH_FILE}" "${LIGHTTPD_AUTH_FILE_BKP}" 2>/dev/null ; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AuthFileBkpCopyFailed AuthFile=${LIGHTTPD_AUTH_FILE} AuthFileBkp=${LIGHTTPD_AUTH_FILE_BKP}"
        err_exit 1 "AuthFileBkpCopyFailed"
    fi
fi

# changing ownership/permissions of the temporary file with new credentials, the following mv command
# must replace LIGHTTPD_AUTH_FILE with LIGHTTPD_AUTH_FILE_TMP with this new ownership/permissions:
#
# root@taser-etmv2:~# touch tst1
# root@taser-etmv2:~# ls -al tst*
# -rw-r-----    1 root     root             0 Nov 22 00:17 tst1
# root@taser-etmv2:~# touch tst2
# root@taser-etmv2:~# chown root:wwwrun tst2 && chmod 440 tst2
# root@taser-etmv2:~# ls -al tst*
# -rw-r-----    1 root     root             0 Nov 22 00:17 tst1
# -r--r-----    1 root     wwwrun           0 Nov 22 00:17 tst2
# root@taser-etmv2:~# mv tst2  tst1
# root@taser-etmv2:~# ls -al tst*
# -r--r-----    1 root     wwwrun           0 Nov 22 00:17 tst1
#
if ! (/bin/chown root:wwwrun "${LIGHTTPD_AUTH_FILE_TMP}" 2>/dev/null && /bin/chmod 440 "${LIGHTTPD_AUTH_FILE_TMP}" 2>/dev/null) ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=AuthFileTmpChownChmodFailed AuthFileTmp=${LIGHTTPD_AUTH_FILE_TMP}"
    err_exit 1 "AuthFileTmpChownChmodFailed"
fi

if ! /bin/mv "${LIGHTTPD_AUTH_FILE_TMP}" "${LIGHTTPD_AUTH_FILE}" 2>/dev/null ; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=MoveTmp2AuthFileFailed AuthFileTmp=${LIGHTTPD_AUTH_FILE_TMP} AuthFile=${LIGHTTPD_AUTH_FILE}"
    err_exit 1 "MoveTmp2AuthFileFailed"
fi

# update etm.etm.web_admin_user
if ! (/www/scripts/uci-option.sh "set" "etm.etm.web_admin_user" "${WEB_ADMIN_NEW_USER}" && /www/scripts/uci-commit-etm.sh) ; then
    err_exit 1 "EtmConfigSaveFailed"
fi

# Only print first 16 chars of hash
log_info_msg_no_echo "${SCRIPT_NAME}" "Event=WebAdminUserPasswdUpdated Hash=${CALC_NEW_HASH:0:16}****************"

echo "DONE:${SCRIPT_NAME}"
exit 0
