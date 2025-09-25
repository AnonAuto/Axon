#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage: /usr/bin/sudo /www/scripts/ecom.sh <sub-command> <parameters>

SCRIPT_NAME=ecom.sh

source /etm/bin/etm-common.sh

config_load etm
config_get AUTH operation authenticated

if [ "$AUTH" != "1" ]; then exit 1; fi

config_get AGENCY operation agency_domain
config_get AGENCY_ID operation agency_id
config_get ACCESS operation access_key
config_get SECRET operation secret_key

# /******** Access Key system ***********
# Add three headers to the API call, login not required.
# x-tasr-date = ISO 8601 Timestamp of the current UTC time.
# x-tasr-authorization = AccessKeyId:Signature
# x-tasr-expires = Five minutes from x-tasr-date
#
# Signature = Base64( HMAC-SHA1( UTF-8-Encoding-Of(SecretAccessKeyID, StringToSign ) ) );
#
# StringToSign = HTTP-Verb|Content-Type|Date|DomainName|expirationDate
# (Note that the dates used here must match x-tasr-date and x-tasr-expires headers respectively)
# ***************************************/

TIME_NOW=$(date +%s)
X_TASR_DATE=$(date -u --date=@$TIME_NOW +%Y-%m-%dT%H:%M:%SZ)
X_TASR_EXPIRES=$(date -u --date=@$((TIME_NOW + 5 * 60)) +%Y-%m-%dT%H:%M:%SZ)

sign() {
    # $1 is the http method (GET, POST, ...)
    # $2 is the content type (application/x-www-form-urlencoded, ...)
    if [ -z "${2+xxx}" ]; then content_type="application/x-www-form-urlencoded";
    else content_type="$2";
    fi
    StringToSign="$1|$content_type|${X_TASR_DATE}|${AGENCY}|${X_TASR_EXPIRES}"
    # >&2 echo "$StringToSign"
    Signature=$(echo -n "${StringToSign}" | openssl dgst -binary -sha1 -hmac "${SECRET}" | openssl enc -base64)
    X_TASR_AUTHORIZATION="${ACCESS}:${Signature}"
    echo "$X_TASR_AUTHORIZATION"
}

# Example request using the sign method to authenticate
# curl -s --location \
# --cacert '/etc/ssl/ca-bundle.crt' \
# --header "Content-Type: application/x-www-form-urlencoded" \
# --header "x-tasr-date: ${X_TASR_DATE}" \
# --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
# --header "x-tasr-authorization: $(sign GET)" \
# --request GET "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/homes/list?includePointOfContactInfo=true&format=json"


# if there is a sub command then run it in the sub-script, passing the rest of argument to it
if [ ! -z $1 ] ; then
    script=$( echo "$1" | sed -r 's|[,.*:;"%?&$@!\/\|\(\){} '\'']||g' )
    if [ -f "/www/scripts/ecom-$script.sh" ]; then source "/www/scripts/ecom-$script.sh"; fi
fi
