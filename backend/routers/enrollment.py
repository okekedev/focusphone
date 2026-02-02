"""
Enrollment token routes
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone
import uuid
import os
import io
import qrcode

from database import get_db, EnrollmentToken, User
from routers.auth import get_current_user

router = APIRouter()

# Server URL for enrollment
SERVER_URL = os.getenv("MDM_SERVER_URL", "http://localhost:8000")


# MARK: - Schemas

class TokenResponse(BaseModel):
    token: str
    expiresAt: datetime
    enrollmentURL: str
    qrCodeURL: str
    profileId: str | None = None


class CreateTokenRequest(BaseModel):
    profileId: str | None = None


# MARK: - Routes

@router.post("/token", response_model=TokenResponse)
async def create_enrollment_token(
    request: CreateTokenRequest = CreateTokenRequest(),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create an enrollment token for a new device"""
    token = EnrollmentToken(
        id=str(uuid.uuid4()),
        token=str(uuid.uuid4()),
        owner_id=user.id,
        profile_id=request.profileId,
        expires_at=datetime.now(timezone.utc) + timedelta(hours=1)
    )

    db.add(token)
    await db.commit()
    await db.refresh(token)

    enrollment_url = f"{SERVER_URL}/enroll/{token.token}"
    qr_url = f"{SERVER_URL}/api/enrollment/qr/{token.token}"

    return TokenResponse(
        token=token.token,
        expiresAt=token.expires_at,
        enrollmentURL=enrollment_url,
        qrCodeURL=qr_url,
        profileId=token.profile_id
    )


@router.get("/token/{token}", response_model=TokenResponse)
async def get_enrollment_token(
    token: str,
    db: AsyncSession = Depends(get_db)
):
    """Get enrollment token details (public - for enrollment flow)"""
    result = await db.execute(
        select(EnrollmentToken).where(EnrollmentToken.token == token)
    )
    enrollment_token = result.scalar_one_or_none()

    if not enrollment_token:
        raise HTTPException(status_code=404, detail="Token not found")

    if not enrollment_token.is_valid:
        raise HTTPException(status_code=400, detail="Token expired or already used")

    enrollment_url = f"{SERVER_URL}/enroll/{enrollment_token.token}"
    qr_url = f"{SERVER_URL}/api/enrollment/qr/{enrollment_token.token}"

    return TokenResponse(
        token=enrollment_token.token,
        expiresAt=enrollment_token.expires_at,
        enrollmentURL=enrollment_url,
        qrCodeURL=qr_url,
        profileId=enrollment_token.profile_id
    )


@router.get("/qr/{token}")
async def get_enrollment_qr(
    token: str,
    db: AsyncSession = Depends(get_db)
):
    """Get QR code image for enrollment (scan with phone to enroll)"""
    result = await db.execute(
        select(EnrollmentToken).where(EnrollmentToken.token == token)
    )
    enrollment_token = result.scalar_one_or_none()

    if not enrollment_token:
        raise HTTPException(status_code=404, detail="Token not found")

    if not enrollment_token.is_valid:
        raise HTTPException(status_code=400, detail="Token expired or already used")

    enrollment_url = f"{SERVER_URL}/enroll/{enrollment_token.token}"

    # Generate QR code
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(enrollment_url)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")

    # Save to bytes
    img_bytes = io.BytesIO()
    img.save(img_bytes, format="PNG")
    img_bytes.seek(0)

    return StreamingResponse(img_bytes, media_type="image/png")
