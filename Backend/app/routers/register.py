from fastapi import APIRouter, HTTPException, Request

from app import storage
from app.crypto_utils import is_valid_public_key
from app.models import RegisterRequest, RegisterResponse
from app.rate_limit import check_rate_limit, client_ip

router = APIRouter()


@router.post("/register", response_model=RegisterResponse)
def register(req: RegisterRequest, request: Request) -> RegisterResponse:
    if not check_rate_limit(f"register:{client_ip(request)}"):
        raise HTTPException(status_code=429, detail="Too many registration attempts, try again later.")

    if not is_valid_public_key(req.publicKey):
        raise HTTPException(status_code=400, detail="publicKey is not a valid P-256 point")

    key_id = storage.register_key(
        device_id=req.deviceId,
        public_key_b64=req.publicKey,
        fingerprint=req.fingerprint,
    )
    return RegisterResponse(keyId=key_id)
