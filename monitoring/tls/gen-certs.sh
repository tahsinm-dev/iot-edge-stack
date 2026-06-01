#!/bin/sh
# Generate a local CA and a server certificate for the MQTT broker's TLS listener.
# Idempotent: keeps existing certificates.
set -e
CERT_DIR="${1:-/certs}"
DAYS=3650
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

if [ -f ca.crt ] && [ -f server.crt ] && [ -f server.key ]; then
  echo "TLS certificates already present - keeping them."
  exit 0
fi

# Certificate authority
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days "$DAYS" \
  -subj "/CN=IoT-Edge-CA" -out ca.crt

# Server certificate signed by the CA
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=mosquitto" -out server.csr
printf 'subjectAltName=DNS:mosquitto,DNS:localhost,IP:127.0.0.1\n' > server.ext
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days "$DAYS" -sha256 -extfile server.ext -out server.crt

rm -f server.csr server.ext ca.srl
chmod 644 ca.crt server.crt server.key
echo "Generated CA + server certificate in $CERT_DIR"
