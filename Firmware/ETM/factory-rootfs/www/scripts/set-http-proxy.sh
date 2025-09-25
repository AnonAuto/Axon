#-------------------------------------------------
#!/bin/sh
#
# Copyright (c) 2021 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#
# Usage: echo "[username]:[password]" | set-http-proxy.sh "proxy-host" "proxy-port" ["test" | "--disable-dns-check=<0|1>" ]
#      proxy-host: must be a valid uri
#      proxy-port: must be a valid port
#      username & password: must follow these characters: a-zA-Z0-9!#()_-
#      test: test connection instead of saving configuration
# Example: echo "admin:$(base64 12345678)" | set-http-proxy.sh
# Special case:
#   To disable proxy send "0" to script.
#     Command: echo "0" | set-http-proxy.sh
#   To use empty username:password send "-" to script.
#     Command: echo "-" | set-http-proxy.sh "proxy-host" "proxy-port"

. /etm/bin/etm-common.sh
SCRIPT_NAME="set-http-proxy.sh"

testProxy() {
    local URL="$1"
    local PROXY_HOST="$2"
    local PROXY_PORT="$3"
    local PROXY_AUTH="$4"
    if [[ -z "${PROXY_AUTH}" ]]; then
        CURL_HOME=/nonexistent; /usr/bin/curl --fail --silent --max-time 10 --proxy-anyauth --proxy "http://${PROXY_HOST}:${PROXY_PORT}" --cacert "${SSL_CA_BUNDLE}" "${URL}" > /dev/null
    else
        CURL_HOME=/nonexistent; /usr/bin/curl --fail --silent --max-time 10 --proxy-anyauth --proxy-user "${PROXY_AUTH}" --proxy "http://${PROXY_HOST}:${PROXY_PORT}" --cacert "${SSL_CA_BUNDLE}" "${URL}" > /dev/null
    fi
    local STATUS=$?
    if [[ ${STATUS} -eq 0 ]]; then
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyTestSuccess URL=https://${AGENCY}/ping"
        echo "DONE:${SCRIPT_NAME}"
        exit 0
    else
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyTestFailed Code=${STATUS} URL=https://${AGENCY}/ping"
        # give specific strings for common curl errors
        # https://everything.curl.dev/usingcurl/returns
        case ${STATUS} in
            5)
                echo "ERR:50/CouldNotResolveProxyHost"
                ;;

            6)
                echo "ERR:51/CouldNotResolveHost"
                ;;

            7)
                echo "ERR:52/FailedToConnectToHost"
                ;;

            28)
                echo "ERR:53/RequestTimeout"
                ;;

            *)
                echo "ERR:70${STATUS}/ProxyTestFailed"
                ;;
        esac
        exit 1
    fi
}

IFS= read -s -r PROXY_AUTH

if [[ "${PROXY_AUTH}" == "0" ]]; then
    if (/www/scripts/uci-option.sh "delete" "etm.proxy" && /www/scripts/uci-commit-etm.sh); then
        config_load etm
        proxy_generate_runtime_config
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=HTTPProxyDisabled"
        echo "DONE:${SCRIPT_NAME}"
        exit 0
    else
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=HTTPProxyDisabledFailed"
        echo "ERR:1/HTTPProxyDisabledFailed"
        exit 1
    fi
fi

PROXY_HOST="$1"
if [[ -z "${PROXY_HOST}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyHostEmpty"
    echo "ERR:1/ProxyHostEmpty"
    exit 1
fi

PROXY_PORT="$2"
if [[ -z "${PROXY_PORT}" ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyPortEmpty"
    echo "ERR:1/ProxyPortEmpty"
    exit 1
fi
if ! echo "${PROXY_PORT}" | grep -qe '^[0-9]\{1,5\}$'; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid port format"
    echo "ERR:1/ProxyPortInvalidFormat"
    exit 1
fi
if [[ "${PROXY_PORT}" -lt 1 ]] || [[ "${PROXY_PORT}" -gt 65535 ]]; then
    log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid port range"
    echo "ERR:1/ProxyPortInvalidRange"
    exit 1
fi

PROXY_CMD="set"
PROXY_OPT_DISABLE_DNS_CHECK="0"
case ${3} in
    "test")
        config_load etm
        config_get AGENCY operation agency_domain
        if [[ -z "${AGENCY}" ]]; then
            AGENCY="time.evidence.com"
        fi
        PROXY_CMD="test"
        ;;

    "--disable-dns-check=0")
        PROXY_OPT_DISABLE_DNS_CHECK="0"
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyConfigEnableDnsCheck"
        ;;

    "--disable-dns-check=1")
        PROXY_OPT_DISABLE_DNS_CHECK="1"
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyConfigDisableDnsCheck"
        ;;

    *)
        ;;
esac

if [[ "${PROXY_AUTH}" == "-" ]]; then
    if [[ "${PROXY_CMD}" == "test" ]]; then
        testProxy "https://${AGENCY}/ping" "${PROXY_HOST}" "${PROXY_PORT}"
    else
        if (/www/scripts/uci-option.sh "delete" "etm.proxy"; \
            /www/scripts/uci-option.sh "set" "etm.proxy" "proxy" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.enabled" "1" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.host" "${PROXY_HOST}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.port" "${PROXY_PORT}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.disable_dns_check" "${PROXY_OPT_DISABLE_DNS_CHECK}" &&
            /www/scripts/uci-commit-etm.sh); then
            # Success!
            config_load etm
            proxy_generate_runtime_config
            log_info_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyInfoSaved"
            echo "DONE:${SCRIPT_NAME}"
            exit 0
        else
            log_err_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyInfoSaveFailed"
            echo "ERR:1/ProxyInfoSaveFailed"
            exit 1
        fi
    fi
else
    # checking for the right format, must contain 1 ":"
    NUM_VAR=$(echo ${PROXY_AUTH} | awk 'BEGIN{FS=":"} {print NF?NF-1:0}')

    if [[ "${NUM_VAR}" -ne "1" ]]; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid format, not in form \"[username]:[password]\""
        echo "ERR:1/ProxyUsernamePasswordInvalidFormat"
        exit 1
    fi

    PROXY_USER="${PROXY_AUTH%%:*}"
    PROXY_AUTH="${PROXY_AUTH#*:}"

    PROXY_PASS="${PROXY_AUTH%%:*}"

    if ! echo "${PROXY_USER}" | grep -qe '^[a-zA-Z0-9!#()_\-]\{2,64\}$'; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid username format"
        echo "ERR:1/ProxyUsernameInvalidFormat"
        exit 1
    fi
    if ! echo "${PROXY_PASS}" | grep -qe '^[a-zA-Z0-9!#()_\-]\{4,64\}$'; then
        log_err_msg_no_echo "${SCRIPT_NAME}" "Invalid password format"
        echo "ERR:1/ProxyPasswordInvalidFormat"
        exit 1
    fi

    if [[ "${PROXY_CMD}" == "test" ]]; then
        testProxy "https://${AGENCY}/ping" "${PROXY_HOST}" "${PROXY_PORT}" "${PROXY_USER}:${PROXY_PASS}"
    else
        KEY=$(proxy_get_encryption_key)
        PROXY_ENCRYPTED_USER=$(proxy_encrypt_data "${PROXY_USER}" "${KEY}")
        PROXY_ENCRYPTED_PASS=$(proxy_encrypt_data "${PROXY_PASS}" "${KEY}")

        if (/www/scripts/uci-option.sh "delete" "etm.proxy"; \
            /www/scripts/uci-option.sh "set" "etm.proxy" "proxy" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.enabled" "1" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.host" "${PROXY_HOST}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.port" "${PROXY_PORT}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.encrypted_un" "${PROXY_ENCRYPTED_USER}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.encrypted_pw" "${PROXY_ENCRYPTED_PASS}" &&
            /www/scripts/uci-option.sh "set" "etm.proxy.disable_dns_check" "${PROXY_OPT_DISABLE_DNS_CHECK}" &&
            /www/scripts/uci-commit-etm.sh); then
            # Success!
            config_load etm
            proxy_generate_runtime_config
            log_info_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyInfoSaved"
            echo "DONE:${SCRIPT_NAME}"
            exit 0
        else
            log_err_msg_no_echo "${SCRIPT_NAME}" "Event=ProxyInfoSaveFailed"
            echo "ERR:1/ProxyInfoSaveFailed"
            exit 1
        fi
    fi
fi
