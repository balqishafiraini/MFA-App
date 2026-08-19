from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import challenge, register, rotate, verify

app = FastAPI(title="MFA Demo Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(register.router)
app.include_router(challenge.router)
app.include_router(verify.router)
app.include_router(rotate.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
