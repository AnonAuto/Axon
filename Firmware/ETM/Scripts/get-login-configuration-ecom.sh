#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2023 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Detect what login flow the domain wants to go
# /usr/bin/sudo /www/scripts/get-login-configuration.sh <domain>
# /usr/bin/sudo /www/scripts/get-login-configuration.sh test.st.evidence.com

. /etm/bin/etm-common.sh

# Set SCRIPT_NAME for logging purpose
SCRIPT_NAME="get-login-configuration-ecom.sh"

domain=$1
log_msg=""

main() {
        RESULT=$(curl -s -w "\n%{http_code}" --location \
                --cacert "${SSL_CA_BUNDLE}" \
                "https://${domain}/api/oauth2/configuration?clientId=${LOGIN_CLIENT_ID}")
        error_code=$?


        http_code=$(echo "${RESULT}" | tail -n 1 | tr -dc '0-9') 

        if [ "${http_code}" != "200" ]; then
                log_msg="Event=GetLoginConfigFailed Reason=UnexpectedHttpResponse HttpCode=${http_code} Error=${error_code}"
                if [ "${http_code}" = "404" ] || [ "${http_code}" = "501" ]; then
                        echo "ERR:0/LegacyLogin"
                        return 0
                elif [ "${http_code}" = "000" ]; then
                        if is_curl_error_ssl_related "${error_code}"; then
                                echo "ERR:1060/$domain"
                        else
                                echo "ERR:-1/NoResponse"
                        fi
                        return 0
                fi

                return 1
        fi

        # Remove the last line and concat multiple lines into one single line
        # Example input
        # {
        #       "regionCode": "st",
        # }
        # 200
        # Example output
        # { "regionCode": "st" }
        RESULT=$(echo "${RESULT}" | sed '$ d' | tr -d '\n')

        # universalLoginEnable might be removed in the future so we accept it to be not found
        # https://axon.quip.com/270KAID4H9OR/Universal-Login-integration-for-1st-party-native-applications#temp:C:VNW8a4067a3d7d04d02848ec24f3
        universal_login_enable=$(echo "$RESULT" | json_extract universalLoginEnable boolean)
        if [ "${universal_login_enable}" = "true" ] || [ -z "${universal_login_enable}" ]; then
                token_endpoint=$(echo "$RESULT" | json_extract tokenEndpoint) || return 1
                device_authorization_endpoint=$(echo "$RESULT" | json_extract deviceAuthorizationEndpoint) || return 1
                save_login_config "token_endpoint" "${token_endpoint}" || return 1
                save_login_config "device_authorization_endpoint" "${device_authorization_endpoint}" || return 1
                save_login_config "domain" "${domain}" || return 1
                log_msg="Event=LoginStart"
                echo "ERR:0/UniversalLogin"
        else
                echo "ERR:0/LegacyLogin"
        fi
}

if ! main; then
        log_msg="Event=GetLoginConfigFailed Reason=InternalError"
        echo "ERR:100/InternalError"
fi
log_info_msg_no_echo "${SCRIPT_NAME}" "$log_msg"
