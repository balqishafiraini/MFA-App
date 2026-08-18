from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    deviceId: str
    publicKey: str = Field(..., description="Base64-encoded raw EC point (X9.63: 0x04 || X || Y)")
    fingerprint: str = Field(..., description="SHA-256 hash of device fingerprint fields, hex-encoded")


class RegisterResponse(BaseModel):
    keyId: str


class ChallengeResponse(BaseModel):
    challenge: str
    nonce: str


class VerifyRequest(BaseModel):
    keyId: str
    signature: str = Field(..., description="Base64-encoded DER ECDSA signature")
    fingerprint: str


class VerifyResponse(BaseModel):
    verified: bool


class RotateRequest(BaseModel):
    keyId: str
    newPublicKey: str = Field(..., description="Base64-encoded raw EC point of the new key")
    signature: str = Field(..., description="challenge+nonce signed with the OLD (currently registered) key")


class RotateResponse(BaseModel):
    rotated: bool
