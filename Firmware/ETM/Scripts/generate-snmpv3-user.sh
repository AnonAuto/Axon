#-------------------------------------------------
#!/bin/sh
#
# Copyright (c) 2016 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: echo "[username];[password];[security];[authentication];[encryption];[(optional)encryption password];" | generate-snmpv3-user.sh
#      password: (base64 encoded) must have at least 8 characters before encoded.
#      security: auth|priv
#      authentication: MD5|SHA
#      encryption: DES|AES
# Example: echo "admin;12345678;auth;MD5;DES;abcdefgh;" | generate-snmpv3-user.sh
# Special case: To disable snmp server send "0" to script
# Command: echo "0" | generate-snmpv3-user.sh

. /etm/bin/etm-common.sh
SCRIPT_NAME="generate-snmpv3-user.sh"

USR_DIR="/etc/snmp/usr"
PIDFILE="/var/run/snmpd.pid"

CONFIG_FILE="/etc/snmp/snmpd.conf"
USR_FILE="${USR_DIR}/snmpd.conf"
IFS= read -s -r SNMPD_CONF

SNMP_USER=""
SNMP_PASS=""
SNMP_SEC=""
SNMP_AUTH=""
SNMP_ENC=""
SNMP_ENCPASS=""

validate_input() {
    if [[ -z "${SNMP_USER}" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidSnmpUsername"
        exit 1
    fi

    if [[ -z "${SNMP_PASS}" || "${#SNMP_PASS}" -lt "8" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidSnmpPassword"
        exit 1
    fi

    if [[ "${SNMP_AUTH}" != "MD5" && "${SNMP_AUTH}" != "SHA" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidSnmpAuthentication"
        exit 1
    fi

    if [[ "${SNMP_ENC}" != "DES" && "${SNMP_ENC}" != "AES" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidSnmpEncryption"
        exit 1
    fi

    # only if encryption password is used
    if [[ "${SNMP_SEC}" == 'priv' && ! -z "${SNMP_ENCPASS}" ]]; then
        # Decode encrypted password from base64
        SNMP_ENCPASS="$(echo "${SNMP_ENCPASS}" | /usr/bin/openssl enc -base64 -d -A)"
        if [[ "${#SNMP_ENCPASS}" -lt "8" ]]; then
            log_err_msg_no_echo "${SCRIPT_NAME}" "Event=InvalidSnmpEncryptionPassword"
            exit 1
        fi
    fi
}

stop_snmp_if_running() {
    # Checking for snmpd still running, stop if it is
    if /bin/ps -e | egrep ' snmpd *$' > /dev/null 2>&1 ; then
        log_info_msg_no_echo "${SCRIPT_NAME}"  "Event=snmpd_running Action=Stopping..."
        /etc/init.d/snmpd stop
        sleep 2
        if [ ! -f "$PIDFILE" ]; then
            log_info_msg_no_echo "${SCRIPT_NAME}" "Event=snmpd_stopped"
        else
            log_err_msg_no_echo "${SCRIPT_NAME}" "Event=Unable_stop_snmpd"
            exit 1
        fi
    fi
}

restart_snmp() {
    # Restarting snmpd server
    /etc/init.d/snmpd restart
}

if [[ "${SNMPD_CONF}" == "0" ]]; then
    ENABLED_SNMP="0"
    log_info_msg_no_echo "${SCRIPT_NAME}" "Event=SNMPdisabled."
    /bin/rm "${CONFIG_FILE}" "${USR_FILE}"
    stop_snmp_if_running
    exit 0
else
    # checking for the right format, at least contain 6 ";"
    NUM_VAR=$(echo ${SNMPD_CONF} |  awk 'BEGIN{FS=";"} {print NF?NF-1:0}')

    if [[ "${NUM_VAR}" -ne "6" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid format, not in form \"[username];[password];[security];[authentication];[encryption];[(optional)encryption password];\""
        exit 1
    fi

    ENABLED_SNMP="1"
    SNMP_USER="${SNMPD_CONF%%;*}"
    SNMPD_CONF="${SNMPD_CONF#*;}"

    SNMP_PASS="${SNMPD_CONF%%;*}"
    SNMPD_CONF="${SNMPD_CONF#*;}"

    SNMP_SEC="${SNMPD_CONF%%;*}"
    SNMPD_CONF="${SNMPD_CONF#*;}"

    SNMP_AUTH="${SNMPD_CONF%%;*}"
    SNMPD_CONF="${SNMPD_CONF#*;}"

    SNMP_ENC="${SNMPD_CONF%%;*}"
    SNMPD_CONF="${SNMPD_CONF#*;}"

    SNMP_ENCPASS="${SNMPD_CONF%%;*}"

    # Decode password from base64.
    SNMP_PASS="$(echo "${SNMP_PASS}" | /usr/bin/openssl enc -base64 -d -A)"

    validate_input
fi

stop_snmp_if_running
# Create if not exits USR_DIR and add password(s). Permission and ownership will be set by snmpd.
# The snmpd will convert plain text "createUser + security settings" into digest form.
/bin/mkdir -p "${USR_DIR}"
touch "${USR_FILE}"
USER_AUTH="${SNMP_USER} ${SNMP_AUTH} \"${SNMP_PASS}\""
USER_ENC="${SNMP_ENC}"
if [[ "${SNMP_SEC}" == 'auth' ]]; then
    USER_ENC=""
else
    if [[ "${SNMP_SEC}" == 'priv' && ! -z "${SNMP_ENCPASS}" ]]; then
        # adding encryption password to createUser
        USER_ENC="${SNMP_ENC} \"${SNMP_ENCPASS}\""
    fi
fi
echo "createUser ${USER_AUTH} ${USER_ENC}" > "${USR_FILE}"

# Saving changes to uci security configuration
if (/sbin/uci set etm.etm.snmp_sec="${SNMP_SEC}") ; then
    # Success!
    log_info_msg_no_echo "${SCRIPT_NAME}"  "Event=GenerateSnmpUserSuccess"
else
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=FailedSettingSnmpSecurity"
    exit 1
fi