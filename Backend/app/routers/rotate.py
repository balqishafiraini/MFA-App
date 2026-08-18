from fastapi import APIRouter, HTTPException

from app import storage
from app.crypto_utils import is_valid_public_key, verify_signature
from app.models import RotateRequest, RotateResponse
from app.rate_limit import check_rate_limit

router = APIRouter()


@router.post("/rotate", response_model=RotateResponse)
def rotate(req: RotateRequest) -> RotateResponse:
    if not check_rate_limit(f"rotate:{req.keyId}"):
        raise HTTPException(status_code=429, detail="Too many rotation attempts, try again later.")

    registered = storage.get_key(req.keyId)
    if registered is None:
        raise HTTPException(status_code=404, detail="Unknown keyId")

    if not is_valid_public_key(req.newPublicKey):
        raise HTTPException(status_code=400, detail="newPublicKey is not a valid P-256 point")

    pending = storage.consume_challenge(req.keyId)
    if pending is None:
        raise HTTPException(status_code=401, detail="No valid challenge pending for this keyId")

    # The signature must come from the OLD key. That is what proves the request
    # is really from the registered device, rather than someone simply posting a
    # public key of their own.
    message = (pending.challenge + pending.nonce).encode()
    if not verify_signature(registered.public_key_b64, message, req.signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    storage.rotate_key(req.keyId, req.newPublicKey)
    return RotateResponse(rotated=True)
