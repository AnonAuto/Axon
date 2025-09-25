#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2023 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Get the verification uri and login code via saved endpoint
# /usr/bin/sudo /www/scripts/get-access-token.sh

. /etm/bin/etm-common.sh

# Set SCRIPT_NAME for logging purpose
SCRIPT_NAME="get-access-token.sh"

log_msg=""

signal_success() {
        http_code=$1
        status="RetrievedToken"
        log_msg="Status=$status HttpCode=$http_code"
        echo "ERR:0/$status"
}

signal_authorization_pending_error() {
        http_code=$1
        error=$2
        status="AuthorizationPending"
        log_msg="Status=$status HttpCode=$http_code Error=$error"
        echo "ERR:0/$status"
}

signal_rate_error() {
        http_code=$1
        status="ExponentialBackoff"
        log_msg="Status=$status HttpCode=$http_code"
        echo "ERR:0/$status"
}

signal_terminative_error() {
        error=$1
        error_description=$2
        http_code=$3
        status="Terminate"
        log_msg="Status=$status HttpCode=$http_code Error=$error Desc=\"$error_description\""
        echo "ERR:100/$error"
}

main() {
        token_endpoint=$(load_login_config token_endpoint) || return 1
        device_code=$(load_login_config device_code) || return 1
        code_verifier=$(load_login_config code_verifier) || return 1
        
        RESULT=$(curl -w "\n%{http_code}" -s --location --request POST \
                --cacert "${SSL_CA_BUNDLE}" \
                --url "${token_endpoint}" \
                --header "Content-Type: application/x-www-form-urlencoded" \
                --data code_verifier="${code_verifier}" \
                --data device_code="${device_code}" \
                --data client_id="${LOGIN_CLIENT_ID}" \
                --data grant_type="urn:ietf:params:oauth:grant-type:device_code")
        error_code=$?
        
        http_code=$(echo "${RESULT}" | tail -n 1 | tr -dc '0-9') 
        RESULT=$(echo "${RESULT}" | sed '$ d' | tr -d '\n')

        # Error handling guide: https://axon.quip.com/MNJLAP30HanM/Guide-Universal-Login-integration-with-OAuth-20-Device-Authorization-Grant#temp:C:Xfeba4a15d48aca4f8883691a44e
        case "$http_code" in
                "200")
                        access_token=$(echo "$RESULT" | json_extract access_token) || return 1
                        save_login_config access_token "${access_token}" || return 1
                        signal_success "${http_code}"
                        ;;
                "400")
                        error=$(echo "$RESULT" | json_extract error) || return 1
                        error_description=$(echo "$RESULT" | json_extract error_description) # it's ok to have this empty

                        if [ "$error" = "authorization_pending" ] || [ "$error" = "slow_down" ]; then
                                signal_authorization_pending_error "${http_code}" "${error}"
                        else
                                signal_terminative_error "${error}" "${error_description}" "${http_code}"
                        fi
                        ;;
                "408" | "429")
                        signal_rate_error "${http_code}"
                        ;;
                *)
                        # 401, 403, 500 and others
                        if [ "${http_code}" = "000" ]; then
                                error="$error_code"
                                error_description="nil"
                        else
                                error=$(echo "$RESULT" | json_extract error) # undefined response and not guarantee to have error field
                                error_description=$(echo "$RESULT" | json_extract error_description) # it's ok to have this empty
                                error=${error:-"nil"}
                                error_description=${error_description:-"nil"}
                        fi
                        signal_terminative_error "${error}" "${error_description}" "${http_code}"
                        ;;
        esac
}

if ! main; then
        log_msg="Status=InternalError"
        echo "ERR:100/InternalError"
fi
log_info_msg_no_echo "${SCRIPT_NAME}" "Event=LoginDeviceAccessTokenStatus $log_msg"
