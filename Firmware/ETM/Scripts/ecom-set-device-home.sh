#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Do not call this script directly but using ecom.sh instead:
# /usr/bin/sudo /www/scripts/ecom.sh set-device-home "device-home-id"
# $2 should have the device home id
# if not then remove the device home for this device

config_get DEVICE_ID   etm device_id
config_get DEVICE_HOME_ID   etm device_home_id

# Cannot proceed if there is no device_id
if [ -z $DEVICE_ID ] ; then exit 1; fi

data="{\"data\":[{\"id\":\"${DEVICE_ID}\"}]}"

if [ -z "${2+xxx}" ]
then
    # Remove device home
    #
    RESULT=$(curl -o /dev/null -s -w "%{http_code}\n" --location \
            --cacert '/etc/ssl/ca-bundle.crt' \
            --header "Content-Type: application/json" \
            --header "x-tasr-date: ${X_TASR_DATE}" \
            --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
            --header "x-tasr-authorization: $(sign PATCH "application/json" )" \
            --request PATCH "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/home/remove" \
            --data "$data" )
    # sample return value:
    # {"data":[{"type":"device","id":"f94b6d4f-8a95-4668-8953-dc3c89295de3","attributes":{"serial":"X79059050","status":"active","status2":"instock","make":"TASER","model":"taser_etm_flex_2","friendlyName":"DevDock1","warranties":[],"warrantyExpiry":null,"preferences":[],"deviceErrors":[],"firmwareVersion":null,"canary":null,"dateAssigned":null,"homeId":null,"lastUploadDateTime":null},"relationships":{"owner":{"data":{"type":"agency","id":"885AADD7-3F93-430E-BA17-6B414D8DA522"},"links":{"self":"/api/v1/agencies/885AADD7-3F93-430E-BA17-6B414D8DA522"}},"updatedBy":{"data":{"type":"authToken","id":"292C9DAD-B6B1-4002-BFD9-66DECD4E8F35"},"links":{"self":""}},"agency":{"data":{"type":"agency","id":"885aadd7-3f93-430e-ba17-6b414d8da522"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522"}}},"status":"active","status2":"instock","errorInfo":"ok"}]}
else
    if [ "$DEVICE_HOME_ID" == "$2"]; then exit 0; fi
    # Set device home to ecom
    #
    RESULT=$(curl -o /dev/null -s -w "%{http_code}\n" --location \
            --cacert '/etc/ssl/ca-bundle.crt' \
            --header "Content-Type: application/json" \
            --header "x-tasr-date: ${X_TASR_DATE}" \
            --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
            --header "x-tasr-authorization: $(sign PATCH "application/json" )" \
            --request PATCH "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/home/assign?homeId=${2}" \
            --data "$data" )
    # sample return value:
    # {"data":[{"type":"device","id":"f94b6d4f-8a95-4668-8953-dc3c89295de3","attributes":{"serial":"X79059050","status":"active","status2":"instock","make":"TASER","model":"taser_etm_flex_2","friendlyName":"DevDock1","warranties":[],"warrantyExpiry":null,"preferences":[],"deviceErrors":[],"firmwareVersion":null,"canary":null,"dateAssigned":null,"homeId":"aba0a51c-97d2-42f5-bbae-9c75cd7f8876","lastUploadDateTime":null},"relationships":{"owner":{"data":{"type":"agency","id":"885AADD7-3F93-430E-BA17-6B414D8DA522"},"links":{"self":"/api/v1/agencies/885AADD7-3F93-430E-BA17-6B414D8DA522"}},"updatedBy":{"data":{"type":"authToken","id":"292C9DAD-B6B1-4002-BFD9-66DECD4E8F35"},"links":{"self":""}},"agency":{"data":{"type":"agency","id":"885aadd7-3f93-430e-ba17-6b414d8da522"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522"}}},"status":"active","status2":"instock","errorInfo":"ok"}],"included":[{"type":"user","id":"18baf9c0-8ca4-4b34-97f9-544858db3945","attributes":{"firstName":"Nathan","lastName":"Grubb","badgeNumber":"ngrubb","email":"ngrubb@axon.com"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522/users/18baf9c0-8ca4-4b34-97f9-544858db3945"}},{"type":"deviceHome","id":"aba0a51c-97d2-42f5-bbae-9c75cd7f8876","attributes":{"name":"FWVN Office","pointOfContactId":"18baf9c0-8ca4-4b34-97f9-544858db3945"}}]}
fi

if [ "$RESULT" != "200" ]; then exit 1; fi
