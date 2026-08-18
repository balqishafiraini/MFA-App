"""ECDSA P-256 signature verification.

The backend only ever holds public keys, so nothing here can create a signature —
it can only check one.
"""

import base64

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicKey


def load_public_key(public_key_b64: str) -> EllipticCurvePublicKey:
    """Decodes a raw X9.63 EC point (0x04 || X || Y), the format iOS exports."""
    raw = base64.b64decode(public_key_b64, validate=True)
    return ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), raw)


def is_valid_public_key(public_key_b64: str) -> bool:
    """Checked at registration, so a malformed key is rejected up front instead of
    silently failing every later login."""
    try:
        load_public_key(public_key_b64)
        return True
    except (ValueError, TypeError):
        return False


def verify_signature(public_key_b64: str, message: bytes, signature_b64: str) -> bool:
    try:
        public_key = load_public_key(public_key_b64)
        signature = base64.b64decode(signature_b64, validate=True)
        public_key.verify(signature, message, ec.ECDSA(hashes.SHA256()))
        return True
    except (InvalidSignature, ValueError, TypeError):
        # Any failure is reported the same way — the caller must not learn
        # whether it was the encoding, the key, or the signature that was wrong.
        return False
