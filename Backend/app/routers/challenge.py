from fastapi import APIRouter, HTTPException, Request

from app import storage
from app.models import ChallengeResponse
from app.rate_limit import check_rate_limit, client_ip

router = APIRouter()


@router.get("/challenge", response_model=ChallengeResponse)
def get_challenge(keyId: str, request: Request) -> ChallengeResponse:
    if not check_rate_limit(f"challenge:{client_ip(request)}"):
        raise HTTPException(status_code=429, detail="Too many challenge requests, try again later.")

    if storage.get_key(keyId) is None:
        raise HTTPException(status_code=404, detail="Unknown keyId")

    pending = storage.issue_challenge(keyId)
    return ChallengeResponse(challenge=pending.challenge, nonce=pending.nonce)
