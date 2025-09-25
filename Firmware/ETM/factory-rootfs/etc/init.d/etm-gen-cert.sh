#!/bin/sh
#-------------------------------------------------
#
# Copyright (c) 2013 TASER International, Inc.
# All Rights Reserved
# TASER Data Classification: CONFIDENTIAL
#

# Check private key and certificate, re-generate them if needed.
# This script called at boot time as a part of a boot chain and during runtime by etm-watchdog.sh.
# At boot time it is called without any command line parameters but etm-watchdog.sh calls it 
# with --force-ip-check option, so it does additional check for the certificate.
#
# Please note: In the boot chain it MUST be after ifplugd but before lighttpd. 
#
# Return values:
#     0 - no errors, key/cert unchanged
#     1 - error
#     2 - no error, key and/or cert re-generated

. /etm/bin/etm-common.sh

HTTPS_KEY="${HTTPS_SECRET_DIR}/https.key"
HTTPS_CNF="${HTTPS_SECRET_DIR}/https.cnf"
HTTPS_CERT="${HTTPS_SECRET_DIR}/https.crt"
HTTPS_SECRET="${HTTPS_SECRET_DIR}/secret.pem"

check_RSA_key() {
    local KEY="$1"
    local OUTPUT="$(openssl rsa -in ${KEY} -check -noout 2>/dev/null)"
    if [[ "$(echo ${OUTPUT} | grep "RSA key ok" | wc -l)" -ne 0 ]] ; then
        # check passed, key is OK
        return 0
    fi

    # error
    return 1
}

check_cert() {
    # Please note: this function depends on LAN_IP, WAN_IP and FORCE_IP_CHECK global variables
    local CERT="$1"
    if ! openssl x509 -in "${CERT}" -text -noout > /dev/null 2>&1 ; then
        # unable to read the certificate, re-generate!
        return 1
    fi

    # Check if current certificate has the desired keyUsage defined in HTTPS_CNF
    # Example output
    # root@taser-etmv2:~# openssl x509 -in /etm/secret/https.crt -noout -ext keyUsage
    # X509v3 Key Usage:
    #    Digital Signature, Key Encipherment
    match_key_usage=$(openssl x509 -in "${CERT}" -noout -ext keyUsage | grep "Key Encipherment" | grep "Digital Signature")
    if [ -z "$match_key_usage" ]; then
        log_info_msg "etm-gen-cert.sh" "KeyUsage from the certificate is invalid."
        return 1
    fi

    # in the boot mode this function checks only the fact that certificate is present and
    # can be opened, so this script is called without any parameters, FORCE_IP_CHECK=0 and the following
    # block of code is completely ignored

    if [[ "${FORCE_IP_CHECK}" == "1" ]] ; then
        # get IP1 and IP2 addresses from X509v3 Subject Alternative Name
        # IP1 is for LAN_IP, IP2 (if present) is for WAN_IP
        local CERT_IPS="$(openssl x509 -in "${CERT}" -text -noout | grep "IP Address")"
        # awk fields depend upon the alt name orders in the cert generation below.
        # example line:
        #      1                  3                    4                  6
        # DNS:10.10.1.1, IP Address:10.10.1.1, DNS:172.17.200.13, IP Address:172.17.200.13
        local CERT_IP1="$(echo "${CERT_IPS}" | awk '{ print $3 }' | grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')"
        local CERT_IP2="$(echo "${CERT_IPS}" | awk '{ print $6 }' | grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')"

        if [[ "${LAN_IP}" != "${CERT_IP1}" ]] ; then
            # incorrect LAN IP in the cert (this is unlikely to happen), re-generate!
            log_info_msg "etm-gen-cert.sh" "IP1='${CERT_IP1}' from the certificate does not match LAN_IP='${LAN_IP}'"
            return 1
        fi

        if [[ ! -z "${WAN_IP}" ]] && [[ "${WAN_IP}" != "${CERT_IP2}" ]] ; then
            # WAN interface has an IP address and it does not match with IP2 in the certificate, re-generate!
            log_info_msg "etm-gen-cert.sh" "IP2='${CERT_IP2}' from the certificate does not match WAN_IP='${WAN_IP}'"
            return 1
        fi
    fi

    # check passed, certificate is OK
    return 0
}

# parse command line parameters
# by default, assume that running at boot time
FORCE_IP_CHECK=0 

if [[ "$1" == "--force-ip-check" ]] ; then
    # executed by etm-watchdog.sh
    FORCE_IP_CHECK=1
fi

# subject for our certificates uses dock's SN as Common Name, so in the browser settings user
# can manage certificates for multiple docks
SUBJ="/CN=${SN}/O=Taser International, Inc./OU=evidence.com/C=US"

# get current IP addresses for LAN and WAN 
LAN_IP="$(get_ip_address "${LAN_IFACE}")"
# at boot time this script runs right after ifplugd; it takes some time to get an IP assigned for WAN interface,
# so WAN_IP might be empty; it should not cause any issues because if the certificate was generated with 2 IP addresses (for WAN and LAN)
# it will not be re-generated again; in case of the very first boot of the dock, this script might generate a cert with LAN IP only,
# but remember, etm-watchdog.sh continues to re-run it, so it will recover and re-generate the cert once it get an IP on WAN interface or
# if WAN IP changes
WAN_IP="$(get_ip_address "${WAN_IFACE}")"

if [[ ! -d "${HTTPS_SECRET_DIR}" ]] ; then
    rm -rf "${HTTPS_SECRET_DIR}"
    if ! mkdir -m 0700 "${HTTPS_SECRET_DIR}" ; then
        log_err_msg "etm-gen-cert.sh" "unable to create ${HTTPS_SECRET_DIR} directory"
        exit 1
    fi

    if ! chown root:root "${HTTPS_SECRET_DIR}" ; then
        log_err_msg "etm-gen-cert.sh" "failed to set root ownership over ${HTTPS_SECRET_DIR} directory"
        exit 1
    fi
fi

EXIT_RC=0

# check private key, re-generate if needed
if ! check_RSA_key "${HTTPS_KEY}" ; then
    log_info_msg "etm-gen-cert.sh" "RSA key check failed for ${HTTPS_KEY}, generating new private key for HTTPS certificate"
    rm -rf "${HTTPS_KEY}"
    # force to re-generate HTTPS certificate
    rm -rf "${HTTPS_CERT}"
    if ! openssl genrsa -out "${HTTPS_KEY}" 2048 ; then
        log_err_msg "etm-gen-cert.sh" "failed to generate private key for HTTPS certificate"
        exit 1
    fi
    EXIT_RC=2
fi

# check certificate, re-generate if needed
if ! check_cert "${HTTPS_CERT}" ; then
    log_info_msg "etm-gen-cert.sh" "certificate check failed for ${HTTPS_CERT}, generating new self-signed HTTPS certificate"
    #this will compute the ip addresses again but here we only care about logging it to syslog
    LAN_IP="$(get_ip_address "${LAN_IFACE}" etm-gen-cert.sh)"
    WAN_IP="$(get_ip_address "${WAN_IFACE}" etm-gen-cert.sh)"

    rm -rf "${HTTPS_CNF}"
    rm -rf "${HTTPS_CERT}"
    # create special configuration file, so our certificate will support LAN_IP and WAN_IP
    cat > "${HTTPS_CNF}" <<EOF
[req_distinguished_name]
countryName = US
organizationalUnitName = Taser International, Inc. 
commonName = ${SN}

[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[v3_req] 
keyUsage = keyEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${LAN_IP}
IP.1 = ${LAN_IP}
EOF
    # warning - our certificate check depends upon the ordering of the alt names.  Don't change it without verifying AWK code above. 
    if [[ ! -z "${WAN_IP}" ]] ; then
        echo "DNS.2 = ${WAN_IP}" >> "${HTTPS_CNF}"
        echo "IP.2 = ${WAN_IP}" >> "${HTTPS_CNF}"
    fi

    # generate self-signed certificate
    if ! openssl req -x509 -new -nodes -sha256 -key "${HTTPS_KEY}" -days 3650 -subj "${SUBJ}" -extensions v3_req -config "${HTTPS_CNF}" -out "${HTTPS_CERT}" ; then
        log_err_msg "etm-gen-cert.sh" "failed to generate HTTPS certificate"
        rm -rf "${HTTPS_CERT}"
        exit 1
    fi
    EXIT_RC=2
fi


if [[ "${EXIT_RC}" -eq 2 ]] ; then
    # re-create HTTPS secret file for lighttpd
    rm -rf "${HTTPS_SECRET}"
    cat "${HTTPS_KEY}" "${HTTPS_CERT}" > "${HTTPS_SECRET}"
fi

exit ${EXIT_RC}
