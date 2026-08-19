import base64

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePublicKey


def load_public_key(public_key_b64: str) -> EllipticCurvePublicKey:
    raw = base64.b64decode(public_key_b64, validate=True)
    return ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), raw)


def is_valid_public_key(public_key_b64: str) -> bool:
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
        return False
