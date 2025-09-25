#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Do not call this script directly but using ecom.sh instead:
# /usr/bin/sudo /www/scripts/ecom.sh set-device-name "device_name"
# $2 should have the device name

config_get DEVICE_NAME etm name
config_get DEVICE_ID   etm device_id

# Cannot proceed if there is no device_id
if [ -z $DEVICE_ID ] ; then exit 1; fi

if [ -z "${2+xxx}" ] ; then exit 1; fi

if [ "$DEVICE_NAME" == "$2"]; then exit 0; fi

data="{ \"type\": \"device\", \"id\": \"${DEVICE_ID}\", \"data\": { \"attributes\": { \"friendlyName\": \"${2}\" } } }"

#
# Set device name to ecom
#
RESULT=$(curl -o /dev/null -s -w "%{http_code}\n"  --location \
        --cacert '/etc/ssl/ca-bundle.crt' \
        --header "Content-Type: application/json" \
        --header "x-tasr-date: ${X_TASR_DATE}" \
        --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
        --header "x-tasr-authorization: $(sign PATCH "application/json" )" \
        --request PATCH "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/$DEVICE_ID" \
        --data "$data" )
# sample return value:
# {"data":{"type":"device","id":"f94b6d4f-8a95-4668-8953-dc3c89295de3","attributes":{"serial":"X79059050","status":"active","status2":"instock","make":"TASER","model":"taser_etm_flex_2","friendlyName":"DevDock1","warranties":[],"warrantyExpiry":null,"preferences":[],"deviceErrors":[],"firmwareVersion":null,"canary":null,"dateAssigned":"2020-06-03T06:47:57.01Z","homeId":null,"lastUploadDateTime":null},"relationships":{"owner":{"data":{"type":"agency","id":"885AADD7-3F93-430E-BA17-6B414D8DA522"},"links":{"self":"/api/v1/agencies/885AADD7-3F93-430E-BA17-6B414D8DA522"}},"updatedBy":{"data":{"type":"authToken","id":"292C9DAD-B6B1-4002-BFD9-66DECD4E8F35"},"links":{"self":""}},"agency":{"data":{"type":"agency","id":"885aadd7-3f93-430e-ba17-6b414d8da522"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522"}}}}}

if [ "$RESULT" != "200" ]; then exit 1; fi
