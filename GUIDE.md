# Testing Guide

How to build, run, and test MFA-App — backend and iOS app.

## 1. Running the Backend

Requires Python 3.11–3.13.

```bash
cd Backend
python3 -m venv venv
./venv/bin/pip install -r requirements.txt

# generate the TLS cert for SSL pinning
./certs/generate.sh
# copy the printed hash into MFA-App/App/AppConfig.swift -> pinnedPublicKeyHash

./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8443 \
  --ssl-keyfile certs/server-key.pem --ssl-certfile certs/server-cert.pem
```

Health check: `curl -k https://localhost:8443/health` → `{"status":"ok"}`
(`-k` because the certificate is self-signed, for local testing only).

Restarting the server (e.g. after code changes or to reset the in-memory
state):

```bash
pkill -f "uvicorn app.main:app"
cd Backend && ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8443 \
  --ssl-keyfile certs/server-key.pem --ssl-certfile certs/server-cert.pem
```

> **Python version note**: if `pip install` fails to build `pydantic-core`
> with a `PyO3's maximum supported version` error, the Python on your system
> is newer than what's supported. Use Python 3.12/3.13 (e.g. via `mise`,
> `pyenv`, or the official python.org installer).

## 2. Automated Tests (Backend)

```bash
cd Backend
./venv/bin/pip install -r requirements-dev.txt
./venv/bin/python -m pytest tests -v
```

16 tests covering: registration + rejection of an invalid public key, unique challenge per request, correct signature verification, **single-use challenge** (anti-replay), challenge expiry, rejection of a signature from a different key, fingerprint mismatch, key rotation (old key rejected after rotation), rotation requiring proof from the old key, an interrupted rotation that self-recovers, device re-registration revoking the old key, and rate limiting.

Tests use a software EC P-256 key in place of the Secure Enclave — from the backend's point of view the two are identical, since all the server ever sees is the public key and the signature.

## 3. Manual Testing with curl

A full `register` → `challenge` → sign with `openssl` → `verify` example (useful for debugging the backend without needing to build the iOS app). The backend must already be running.

```bash
# 1. Generate a "device" keypair with openssl (standing in for the iOS Secure Enclave for this test)
openssl ecparam -name prime256v1 -genkey -noout -out /tmp/client_priv.pem
openssl ec -in /tmp/client_priv.pem -pubout -out /tmp/client_pub.pem

# 2. Convert the public key to raw X9.63 base64 (the format the backend expects)
PUBKEY=$(./Backend/venv/bin/python3 - <<'EOF'
from cryptography.hazmat.primitives import serialization
import base64
pub = serialization.load_pem_public_key(open("/tmp/client_pub.pem", "rb").read())
raw = pub.public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
print(base64.b64encode(raw).decode())
EOF
)
FPRINT=$(echo -n "demo-device-fingerprint-seed" | shasum -a 256 | cut -d' ' -f1)

# 3. Register
KEYID=$(curl -sk -X POST https://localhost:8443/register -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"d1\",\"publicKey\":\"$PUBKEY\",\"fingerprint\":\"$FPRINT\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['keyId'])")

# 4. Get a challenge
CHAL=$(curl -sk "https://localhost:8443/challenge?keyId=$KEYID")
CHALLENGE=$(echo "$CHAL" | python3 -c "import json,sys; print(json.load(sys.stdin)['challenge'])")
NONCE=$(echo "$CHAL" | python3 -c "import json,sys; print(json.load(sys.stdin)['nonce'])")

# 5. Sign challenge+nonce
echo -n "${CHALLENGE}${NONCE}" > /tmp/message.bin
openssl dgst -sha256 -sign /tmp/client_priv.pem -out /tmp/sig.bin /tmp/message.bin
SIG=$(base64 -i /tmp/sig.bin | tr -d '\n')

# 6. Verify
curl -sk -X POST https://localhost:8443/verify -H "Content-Type: application/json" \
  -d "{\"keyId\":\"$KEYID\",\"signature\":\"$SIG\",\"fingerprint\":\"$FPRINT\"}"
# -> {"verified": true}

# 7. Try resending the same signature (replay) -> rejected
curl -sk -X POST https://localhost:8443/verify -H "Content-Type: application/json" \
  -d "{\"keyId\":\"$KEYID\",\"signature\":\"$SIG\",\"fingerprint\":\"$FPRINT\"}"
# -> 401 {"detail":"No valid challenge pending for this keyId"}
```

## 4. Running the iOS App

Minimum iOS 17.0, built with Xcode 16+.

1. Open `MFA-App.xcodeproj` in Xcode.
2. Make sure the backend is running and your iPhone is on the
   same WiFi/hotspot network as your Mac.
3. **Must run on a physical iPhone**, not the Simulator.
4. Edit **[`MFA-App/App/AppConfig.swift`](MFA-App/App/AppConfig.swift)** —
   the only file a tester needs to touch:
   - `backendBaseURL` → `https://<your Mac's LAN IP>:8443` (check with
     `ipconfig getifaddr en0`), not `localhost` — from the iPhone's
     perspective, `localhost` means the iPhone itself, not your Mac.
   - `pinnedPublicKeyHash` → the hash printed by `certs/generate.sh` in
     step 1. If it doesn't match, every request will be rejected by
     `CertificatePinningDelegate` — that's the intended behavior.
5. Build & Run (⌘R) onto your device.
6. On the **Set Up** screen, wait for every check to turn green (the
   register button only becomes active once everything passes) → tap
   **Register This Device** → approve Face ID.
7. On the next screen tap **Log In with Face ID** → approve → you'll land
   on the **Security** screen.

The **Security** screen has a few actions worth testing: **Replace My Key** (key rotation), **Log Out** (returns to the login screen, device stays registered), and **Remove This Device** deletes the key + local `keyId`, useful for demoing re-registration without uninstalling the app.

### Scenarios worth trying manually

- **Simulator block**: run the app on the Simulator, it should immediately
  hit `BlockedView`, not crash.
- **Wrong certificate**: change one character in `pinnedPublicKeyHash`,
  restart the app, the "Server Identity Locked" check on the Set Up screen
  should turn red and the connection to the backend should be rejected.
- **Key rotation**: on the Security screen, tap **Replace My Key**, wait for
  success, Log Out, then log back in — it should still be able to log in
  (confirming the new key is what's being used, not the old one).
- **Reinstall**: uninstall the app from the iPhone, reinstall it, it should
  go back to the **Set Up** screen (not Security), and re-registering should
  get a new `keyId` from the server.
- **Rate limiting**: from the terminal, send rapid repeated `/challenge`
  requests (see part 3) for the same keyId — request #11 onward should get
  a `429`.
