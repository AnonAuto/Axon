#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2020 Axon Enterprise, Inc.
# All Rights Reserved
# Axon Data Classification: CONFIDENTIAL
#
# Usage:
# Do not call this script directly but using ecom.sh instead:
# /usr/bin/sudo /www/scripts/ecom.sh get-device-homes

RESULT=$(curl -s --location \
        --cacert '/etc/ssl/ca-bundle.crt' \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --header "x-tasr-date: ${X_TASR_DATE}" \
        --header "x-tasr-expires: ${X_TASR_EXPIRES}" \
        --header "x-tasr-authorization: $(sign GET)" \
        --request GET "https://$AGENCY/api/v1/agencies/$AGENCY_ID/devices/homes/list?includePointOfContactInfo=true&format=json" )

# sample of return value:
# {"data":[{"type":"deviceHome","id":"aba0a51c-97d2-42f5-bbae-9c75cd7f8876","attributes":{"name":"FWVN Office","pointOfContactId":"18baf9c0-8ca4-4b34-97f9-544858db3945"}}],"included":[{"type":"user","id":"18baf9c0-8ca4-4b34-97f9-544858db3945","attributes":{"firstName":"Nathan","lastName":"Grubb","badgeNumber":"ngrubb","email":"ngrubb@axon.com"},"links":{"self":"/api/v1/agencies/885aadd7-3f93-430e-ba17-6b414d8da522/users/18baf9c0-8ca4-4b34-97f9-544858db3945"}}]}

echo $RESULT
