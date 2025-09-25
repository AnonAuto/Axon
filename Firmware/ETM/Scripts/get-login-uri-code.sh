#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2023 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Get the verification uri and login code via saved endpoint
# /usr/bin/sudo /www/scripts/get-login-uri-code.sh

. /etm/bin/etm-common.sh

# Set SCRIPT_NAME for logging purpose
SCRIPT_NAME="get-login-uri-code.sh"
log_msg=""

gen_code_verifier() { 
        # https://www.rfc-editor.org/rfc/rfc7636.txt
        # Generate random 80 bytes in base64 format, results in 108 characters.
        # The head -c 128 capped is not necessary but keep it as a reminder in future.
        code_verifier=$(openssl rand -base64 80 | tr -d '+/=\n' | head -c 128)

        if [ $? -ne 0 ]; then  # Check if the return value is non-zero
                log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToGenCodeVerifier"
                return 1
        fi

        printf "%s" "${code_verifier}"

        return 0
}

get_code_challenge() {
        read -r code_verifier

        # openssl sha256 -binary        # generates a binary SHA256 hash
        # openssl base64                # encodes the binary hash value in Base64 format.
        # tr '+/' '-_'                  # encodes to Base64UrlEncoding (replace + / with -_ which are not URL-safe
        # tr -d '='                     # remove trailling =
        code_challenge=$(printf "%s" "${code_verifier}" | openssl sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')

        if [ $? -ne 0 ]; then  # Check if the return value is non-zero
                log_info_msg_no_echo "${SCRIPT_NAME}" "Event=FailedToGenCodeChallenge"
                return 1
        fi

        printf "%s" "${code_challenge}"

        return 0
}

main () {
        device_authorization_endpoint=$(load_login_config device_authorization_endpoint) || return 1
        domain=$(load_login_config domain) || return 1

        code_verifier=$(gen_code_verifier) || return 1
        code_challenge=$(printf "%s" "${code_verifier}" | get_code_challenge) || return 1
        code_challenge_method="S256"


        RESULT=$(curl -w "\n%{http_code}" -s --location --request POST \
                --cacert "${SSL_CA_BUNDLE}" \
                --url "${device_authorization_endpoint}" \
                --header "Content-Type: application/x-www-form-urlencoded" \
                --data client_id="${LOGIN_CLIENT_ID}" \
                --data code_challenge="${code_challenge}" \
                --data code_challenge_method="${code_challenge_method}" \
                --data domain="${domain}")
        error_code=$?

        http_code=$(echo "${RESULT}" | tail -n 1 | tr -dc '0-9') 
        RESULT=$(echo "${RESULT}" | sed '$ d' | tr -d '\n')

        if [ "${http_code}" != "200" ]; then
                log_msg="Event=LoginDeviceAuthorizationFailed Reason=UnexpectedHttpResp HttpCode=$http_code Error=$error_code"
                if [ "${http_code}" = "000" ]; then
                        echo "ERR:-1/NoResponse"
                        return 0
                fi
                error=$(echo "$RESULT" | json_extract error) || return 1
                error_description=$(echo "$RESULT" | json_extract error_description)
                error_description=${error_description:-"nil"}
                echo "ERR:100/$error"
                log_msg="Event=LoginDeviceAuthorizationFailed Reason=UnexpectedHttpResp HttpCode=$http_code Error=$error Desc=\"$error_description\""
                return 0
        fi

        # Example response
        # {
        #     "device_code": "276ba95a-8ce2-48ae-b35b-20622321a449",
        #     "user_code": "WDJBMJH",
        #     "verification_uri": "https://id.evidence.com/login/device",
        #     "verification_uri_complete": "https://id.evidence.com/login/device?user_code=WDJBMJH",
        #     "expires_in": 900,
        #     "interval": 15
        # }

        device_code=$(echo "$RESULT" | json_extract device_code) || return 1
        user_code=$(echo "$RESULT" | json_extract user_code) || return 1
        verification_uri=$(echo "$RESULT" | json_extract verification_uri) || return 1
        verification_uri_complete=$(echo "$RESULT" | json_extract verification_uri_complete) # optional
        expires_in=$(echo "$RESULT" | json_extract expires_in number) || return 1
        interval=$(echo "$RESULT" | json_extract interval number) || return 1

        save_login_config device_code "${device_code}" || return 1
        save_login_config code_verifier "${code_verifier}" || return 1
        save_login_config code_challenge "${code_challenge}" || return 1
        save_login_config verification_uri "${verification_uri}" || return 1
        save_login_config verification_uri_complete "${verification_uri_complete}" # optional
        save_login_config user_code "${user_code}" || return 1
        save_login_config expires_in "${expires_in}" || return 1
        save_login_config interval "${interval}" || return 1

        if [ -z "$verification_uri_complete" ]; then
            echo "$verification_uri"
        else
            echo "$verification_uri_complete"
        fi
        echo "$user_code"
        echo "$interval"
        echo "DONE:$SCRIPT_NAME"
        log_msg="Event=LoginDeviceAuthorizationSuccess"
        return 0
}

if ! main; then
        log_msg="Event=LoginDeviceAuthorizationFailed Reason=InternalError"
        echo "ERR:100/InternalError"
fi
log_info_msg_no_echo "${SCRIPT_NAME}" "$log_msg"
