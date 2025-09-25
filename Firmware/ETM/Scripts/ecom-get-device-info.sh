#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Do not call this script directly but using ecom.sh instead:
# /usr/bin/sudo /www/scripts/ecom.sh get-device-info

# config_get DEVICE_NAME etm name
config_get DEVICE_ID   etm device_id
# config_get DEVICE_HOME etm device_home

if [ -z $DEVICE_ID ]
then
    # echo "Get Dock devide id by 'getassignment' api call"

    SERIAL=$(cat /etc/etm-serial)
    RESULT=$(curl -s --location \
            --cacert '/etc/ssl/ca-bundle.crt' \
            --header "Content-Type: application/x-www-form-urlencoded" \
            --header "x-tasr-date: ${X_TASR_DATE}" \
            --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
            --header "x-tasr-authorization: $(sign GET)" \
            --request GET "https://$AGENCY/index.aspx?class=Device&proc=ViewNL&action=getassignment&device_type=taser_etm&device_model=taser_etm_flex&format=json&device_serial_number=$SERIAL" )
    # --request GET "https://$AGENCY/api/v2/agencies/$AGENCY_ID/devices?limit=1&offset=0&serial=$SERIAL") # this is search api, not permitted on Dock

    DEVICE_ID=$(echo $RESULT | sed 's|"owner": {.*}||' | sed 's|.*"id": "\(.*\)".*|\1|' )

    if ( /sbin/uci set etm.etm.device_id="$DEVICE_ID" && /sbin/uci commit etm) ; then
        # Success!
        log_info_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceIdSaved"
    else
        log_err_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceIdFailed"
    fi
fi
# Cannot proceed if there is no device_id
if [ -z $DEVICE_ID ] ; then exit 1; fi


#
# Get device name and location from ecom
#
RESULT=$(curl -s --location \
        --cacert '/etc/ssl/ca-bundle.crt' \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --header "x-tasr-date: ${X_TASR_DATE}" \
        --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
        --header "x-tasr-authorization: $(sign GET)" \
        --request GET "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/$DEVICE_ID?format=json&fields=deviceHome" )
# more: fields=warranties%2Cfirmware%2CdateAssigned%2CdeviceErrors%2CdeviceHome%2Cpreferences"
# sample return value:
# {"data":{"type":"device","id":"f94b6d4f-8a95-4668-8953-dc3c89295de3","attributes":{"serial":"X79059050","status":"active","status2":"instock","make":"TASER","model":"taser_etm_flex_2","friendlyName":"DevDock","warranties":[],"warrantyExpiry":null,"preferences":[],"deviceErrors":[],"firmwareVersion":null,"canary":null,"dateAssigned":null,"homeId":"aba0a51c-97d2-42f5-bbae-9c75cd7f8876","lastUploadDateTime":null},"relationships":{"owner":{"data":{"type":"agency","id":"885AADD7-3F93-430E-BA17-6B414D8DA522"},"links":{"self":"/api/v1/agencies/885AADD7-3F93-430E-BA17-6B414D8DA522"}},"updatedBy":{"data":{"type":"user","id":"7330773A-AA4A-49D6-AA24-605C2E3ADB97"},"links":{"self":"/api/v1/agencies/885AADD7-3F93-430E-BA17-6B414D8DA522/users/7330773A-AA4A-49D6-AA24-605C2E3ADB97"}},"agency":{"data":{"type":"agency","id":"885aadd7-3f93-430e-ba17-6b414d8da522"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522"}}}},"included":[{"type":"user","id":"7330773a-aa4a-49d6-aa24-605c2e3adb97","attributes":{"firstName":"Son","lastName":"Dang","badgeNumber":"ba2d62c7635542a1b9e33ed1","email":"sdang@axon.com"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522/users/7330773a-aa4a-49d6-aa24-605c2e3adb97"}},{"type":"user","id":"18baf9c0-8ca4-4b34-97f9-544858db3945","attributes":{"firstName":"Nathan","lastName":"Grubb","badgeNumber":"ngrubb","email":"ngrubb@axon.com"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522/users/18baf9c0-8ca4-4b34-97f9-544858db3945"}},{"type":"deviceHome","id":"aba0a51c-97d2-42f5-bbae-9c75cd7f8876","attributes":{"name":"FWVN Office","pointOfContactId":"18baf9c0-8ca4-4b34-97f9-544858db3945"}}]}

# # Save the result to uci
#
# _NAME=$(echo $RESULT | sed -nr 's|^.*"type":"device"[^\{\}]*"attributes":\{[^\{\}]*"friendlyName":"([^"]*)".*$|\1|p')
# _HOME=$(echo $RESULT | sed -nr 's|^.*"type":"deviceHome"[^\{\}]*"attributes":\{[^\{\}]*"name":"([^"]*)".*$|\1|p')
# _HOME_ID=$(echo $RESULT | sed -nr 's|^.*"type":"deviceHome"[^\{\}]*"id":"([^"]*)".*$|\1|p')

# if [ -n "$_NAME" ] && [ "$_NAME" != "$DEVICE_NAME" ] ; then
#     DEVICE_NAME="$_NAME"
#     if ( /sbin/uci set etm.etm.name="$DEVICE_NAME" && /sbin/uci commit etm ) ; then
#         log_info_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceNameSaved"
#     else
#         log_err_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceNameFailed"
#     fi
# fi

# if [ -n "$_HOME" ] && [ "$_HOME" != "$DEVICE_HOME" ] ; then
#     DEVICE_HOME="$_HOME"
#     if ( /sbin/uci set etm.etm.device_home="$DEVICE_HOME" &&
#          /sbin/uci set etm.etm.device_home_id="$_HOME_ID" &&
#          /sbin/uci commit etm ) ; then
#         log_info_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceHomeSaved"
#     else
#         log_err_msg_no_echo "${SCRIPT_NAME}" "Event=DeviceHomeFailed"
#     fi
# fi

echo $RESULT
