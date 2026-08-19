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
    _challenges[key_id] = pending
    return pending


def consume_challenge(key_id: str) -> PendingChallenge | None:
    pending = _challenges.pop(key_id, None)

    if pending is None or pending.expires_at < time.time():
        return None
    return pending


def rotate_key(key_id: str, new_public_key_b64: str) -> None:
    _keys[key_id].public_key_b64 = new_public_key_b64


def _revoke_keys_for_device(device_id: str) -> None:
    stale = [key_id for key_id, key in _keys.items() if key.device_id == device_id]

    for key_id in stale:
        del _keys[key_id]
        _challenges.pop(key_id, None)
