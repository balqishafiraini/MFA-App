"""End-to-end tests for the register -> challenge -> verify flow.

A software EC P-256 key stands in for the iPhone's Secure Enclave here: the
backend cannot tell the difference, because all it ever sees is a public key and
a signature. Everything the Secure Enclave adds happens on the device side.
"""

import base64
import hashlib
import time

import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from app import rate_limit, storage
from app.main import app

client = TestClient(app)

FINGERPRINT = hashlib.sha256(b"test-device").hexdigest()


@pytest.fixture(autouse=True)
def clean_state():
    """Every test starts from an empty server."""
    storage._keys.clear()
    storage._challenges.clear()
    rate_limit._windows.clear()
    yield


def new_key() -> ec.EllipticCurvePrivateKey:
    return ec.generate_private_key(ec.SECP256R1())


def public_key_b64(key: ec.EllipticCurvePrivateKey) -> str:
    raw = key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    return base64.b64encode(raw).decode()


def sign(key: ec.EllipticCurvePrivateKey, message: str) -> str:
    signature = key.sign(message.encode(), ec.ECDSA(hashes.SHA256()))
    return base64.b64encode(signature).decode()


def register(key: ec.EllipticCurvePrivateKey, device_id: str = "device-1") -> str:
    response = client.post(
        "/register",
        json={
            "deviceId": device_id,
            "publicKey": public_key_b64(key),
            "fingerprint": FINGERPRINT,
        },
    )
    assert response.status_code == 200
    return response.json()["keyId"]


def get_challenge(key_id: str) -> str:
    """Returns the exact string the device is expected to sign."""
    response = client.get("/challenge", params={"keyId": key_id})
    assert response.status_code == 200
    body = response.json()
    return body["challenge"] + body["nonce"]


def verify(key_id: str, signature: str, fingerprint: str = FINGERPRINT):
    return client.post(
        "/verify",
        json={"keyId": key_id, "signature": signature, "fingerprint": fingerprint},
    )


# --- registration ---------------------------------------------------------


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_register_returns_a_key_id():
    assert len(register(new_key())) > 0


def test_register_rejects_a_malformed_public_key():
    response = client.post(
        "/register",
        json={"deviceId": "d", "publicKey": "not-a-real-key", "fingerprint": FINGERPRINT},
    )
    assert response.status_code == 400


def test_reregistering_a_device_revokes_its_previous_key():
    """What happens after the app is reinstalled: the old Secure Enclave key is
    gone forever, so its registration must not stay valid on the server."""
    first = register(new_key(), device_id="same-device")
    second = register(new_key(), device_id="same-device")

    assert first != second
    assert storage.get_key(first) is None
    assert storage.get_key(second) is not None


# --- challenge ------------------------------------------------------------


def test_challenge_requires_a_known_key_id():
    assert client.get("/challenge", params={"keyId": "nope"}).status_code == 404


def test_challenges_are_unique_per_request():
    key_id = register(new_key())
    assert get_challenge(key_id) != get_challenge(key_id)


# --- verification ---------------------------------------------------------


def test_verify_accepts_a_correct_signature():
    key = new_key()
    key_id = register(key)

    response = verify(key_id, sign(key, get_challenge(key_id)))

    assert response.status_code == 200
    assert response.json() == {"verified": True}


def test_challenge_is_single_use():
    """The core replay defence: a signature that already worked must never work
    a second time."""
    key = new_key()
    key_id = register(key)
    signature = sign(key, get_challenge(key_id))

    assert verify(key_id, signature).status_code == 200
    assert verify(key_id, signature).status_code == 401


def test_challenge_expires():
    key = new_key()
    key_id = register(key)
    message = get_challenge(key_id)
    storage._challenges[key_id].expires_at = time.time() - 1

    assert verify(key_id, sign(key, message)).status_code == 401


def test_verify_rejects_a_signature_from_a_different_key():
    key_id = register(new_key())

    assert verify(key_id, sign(new_key(), get_challenge(key_id))).status_code == 401


def test_verify_rejects_a_mismatched_fingerprint():
    key = new_key()
    key_id = register(key)

    response = verify(key_id, sign(key, get_challenge(key_id)), fingerprint="0" * 64)

    assert response.status_code == 401


def test_failed_verification_still_consumes_the_challenge():
    key = new_key()
    key_id = register(key)
    message = get_challenge(key_id)

    verify(key_id, sign(new_key(), message))  # wrong key

    assert verify(key_id, sign(key, message)).status_code == 401


# --- key rotation ---------------------------------------------------------


def test_rotation_swaps_which_key_is_trusted():
    old_key = new_key()
    new_device_key = new_key()
    key_id = register(old_key)

    rotate = client.post(
        "/rotate",
        json={
            "keyId": key_id,
            "newPublicKey": public_key_b64(new_device_key),
            "signature": sign(old_key, get_challenge(key_id)),
        },
    )
    assert rotate.status_code == 200

    # The identity survives the rotation; only the key behind it changed.
    assert verify(key_id, sign(new_device_key, get_challenge(key_id))).status_code == 200
    assert verify(key_id, sign(old_key, get_challenge(key_id))).status_code == 401


def test_interrupted_rotation_is_recoverable_by_the_client():
    """Rotation commits on the server before the app records it. If the app dies in
    between, it still signs with the old key and gets rejected.

    This pins down the server behaviour the client's recovery path relies on:
    the old key is refused, the new key works, and it keeps working afterwards.
    See AuthenticationService.finishInterruptedRotation.
    """
    old_key = new_key()
    new_device_key = new_key()
    key_id = register(old_key)

    client.post(
        "/rotate",
        json={
            "keyId": key_id,
            "newPublicKey": public_key_b64(new_device_key),
            "signature": sign(old_key, get_challenge(key_id)),
        },
    )

    # What the app sees on the next login, still pointing at the old slot.
    assert verify(key_id, sign(old_key, get_challenge(key_id))).status_code == 401

    # What it finds when it retries with the other slot.
    assert verify(key_id, sign(new_device_key, get_challenge(key_id))).status_code == 200

    # And the recovery holds — the next login is a normal one.
    assert verify(key_id, sign(new_device_key, get_challenge(key_id))).status_code == 200


def test_rotation_requires_proof_from_the_current_key():
    key_id = register(new_key())
    attacker_key = new_key()

    response = client.post(
        "/rotate",
        json={
            "keyId": key_id,
            "newPublicKey": public_key_b64(attacker_key),
            "signature": sign(attacker_key, get_challenge(key_id)),
        },
    )

    assert response.status_code == 401


# --- rate limiting --------------------------------------------------------


def test_verify_is_rate_limited_per_key_id():
    key_id = register(new_key())
    codes = [verify(key_id, "AAAA").status_code for _ in range(12)]

    assert codes[-1] == 429
    assert 429 not in codes[:10]
