#!/bin/sh
# Regenerates the self-signed dev TLS cert used for the SSL pinning demo,
# and prints the pin hash to paste into MFA-App/App/AppConfig.swift.
set -e
cd "$(dirname "$0")"

openssl ecparam -name prime256v1 -genkey -noout -out server-key.pem
openssl req -new -x509 -key server-key.pem -out server-cert.pem -days 3650 -subj "/CN=MFA-Demo-Backend"

echo
echo "Pin hash (paste into AppConfig.pinnedPublicKeyHash):"
python3 - <<'EOF'
from cryptography import x509
from cryptography.hazmat.primitives import serialization
import hashlib

cert = x509.load_pem_x509_certificate(open("server-cert.pem", "rb").read())
raw = cert.public_key().public_bytes(
    encoding=serialization.Encoding.X962,
    format=serialization.PublicFormat.UncompressedPoint,
)
print(hashlib.sha256(raw).hexdigest())
EOF
