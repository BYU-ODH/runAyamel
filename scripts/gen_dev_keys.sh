#!/usr/bin/env bash

services="yvideodev ylexdev yvideo ylex yvideobeta ylexbeta server"

rm_secrets () {
    for x in $services; do
        docker secret rm "$x""_cert"
        docker secret rm "$x""_key"
    done
}

gen_key_cert () {
    BASE_DOMAIN="$1"
    DAYS=1095
    CONFIG_FILE="config.txt"

    cat > $CONFIG_FILE <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
C = CA
ST = BC
L = Vancouver
O = Example Corp
OU = Testing Domain
emailAddress = webmaster@$BASE_DOMAIN
CN = $BASE_DOMAIN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.$BASE_DOMAIN
DNS.2 = $BASE_DOMAIN
EOF

    FILE_NAME="$BASE_DOMAIN"
    rm -f $FILE_NAME.*
    # Generate our Private Key, CSR and Certificate
    # Use SHA-2 as SHA-1 is unsupported from Jan 1, 2017
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -keyout "$FILE_NAME.key" -days $DAYS -out "$FILE_NAME.crt" -config "$CONFIG_FILE"
    # Protect the key
    #chmod 400 "$FILE_NAME.key"
}

rm_secrets
rm -f *.key *.crt

for x in $services; do
    gen_key_cert $x
    docker secret create "$x""_key" $x.key
    docker secret create "$x""_cert" $x.crt
done

rm config.txt *.key *.crt

