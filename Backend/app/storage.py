"""In-memory storage for registered keys and pending challenges.

Deliberately simple. For millions of devices this becomes a database indexed on
keyId, with the short-lived challenges in Redis instead — see SECURITY_QA.md #20.
"""

import base64
import secrets
import time
import uuid
from dataclasses import dataclass

CHALLENGE_TTL_SECONDS = 60


@dataclass
class RegisteredKey:
    key_id: str
    device_id: str
    public_key_b64: str
    fingerprint: str


@dataclass
class PendingChallenge:
    challenge: str
    nonce: str
    expires_at: float


_keys: dict[str, RegisteredKey] = {}

_challenges: dict[str, PendingChallenge] = {}


def register_key(device_id: str, public_key_b64: str, fingerprint: str) -> str:
    # Reinstalling the app loses the Secure Enclave key, so the device comes back
    # with a new one. The old entry can never be used again — drop it rather than
    # leaving a dead public key registered forever.
    _revoke_keys_for_device(device_id)

    key_id = uuid.uuid4().hex[:12]
    _keys[key_id] = RegisteredKey(
        key_id=key_id,
        device_id=device_id,
        public_key_b64=public_key_b64,
        fingerprint=fingerprint,
    )
    return key_id


def get_key(key_id: str) -> RegisteredKey | None:
    return _keys.get(key_id)


def issue_challenge(key_id: str) -> PendingChallenge:
    challenge = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip("=")
    nonce = secrets.token_hex(16)

    pending = PendingChallenge(
        challenge=challenge,
        nonce=nonce,
        expires_at=time.time() + CHALLENGE_TTL_SECONDS,
    )
    # Only one challenge is ever outstanding per key, so asking for a new one
    # invalidates the previous.
    _challenges[key_id] = pending
    return pending


def consume_challenge(key_id: str) -> PendingChallenge | None:
    """Single use: the challenge is removed whether verification then succeeds or
    fails, so the same signature can never be replayed."""
    pending = _challenges.pop(key_id, None)

    if pending is None or pending.expires_at < time.time():
        return None
    return pending


def rotate_key(key_id: str, new_public_key_b64: str) -> None:
    """Swaps the public key material for an existing keyId. The identity
    (keyId) stays the same — only which key it points to changes."""
    _keys[key_id].public_key_b64 = new_public_key_b64


def _revoke_keys_for_device(device_id: str) -> None:
    stale = [key_id for key_id, key in _keys.items() if key.device_id == device_id]

    for key_id in stale:
        del _keys[key_id]
        _challenges.pop(key_id, None)
