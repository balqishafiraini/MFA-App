from fastapi import APIRouter, HTTPException

from app import storage
from app.crypto_utils import verify_signature
from app.models import VerifyRequest, VerifyResponse
from app.rate_limit import check_rate_limit

router = APIRouter()


@router.post("/verify", response_model=VerifyResponse)
def verify(req: VerifyRequest) -> VerifyResponse:
    # Limited per keyId rather than per IP, so brute forcing one account stays
    # blocked even when the attempts are spread across many addresses.
    if not check_rate_limit(f"verify:{req.keyId}"):
        raise HTTPException(status_code=429, detail="Too many verification attempts, try again later.")

    registered = storage.get_key(req.keyId)
    if registered is None:
        raise HTTPException(status_code=404, detail="Unknown keyId")

    # Consumed before any other check, so a failed attempt still burns the challenge.
    pending = storage.consume_challenge(req.keyId)
    if pending is None:
        raise HTTPException(status_code=401, detail="No valid challenge pending for this keyId")

    if req.fingerprint != registered.fingerprint:
        raise HTTPException(status_code=401, detail="Fingerprint mismatch")

    message = (pending.challenge + pending.nonce).encode()
    if not verify_signature(registered.public_key_b64, message, req.signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    return VerifyResponse(verified=True)
