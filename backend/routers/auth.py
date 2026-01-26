"""
Authentication routes - Multi-provider OAuth (Microsoft, Google, Apple)
Supports both Admin Portal (single-tenant) and Parent Portal (multi-tenant)
"""

from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from dotenv import load_dotenv
import httpx
import uuid
import os
from datetime import datetime
from jose import jwt
from jose.exceptions import JWTError
from typing import Optional

from database import get_db, User

# Load .env file
load_dotenv()

router = APIRouter()

# Dev mode - set to True for local testing without OAuth
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"
print(f"DEV_MODE: {DEV_MODE}")

# Master admin email (you - full system access)
MASTER_ADMIN_EMAIL = os.getenv("MASTER_ADMIN_EMAIL", "")

# Microsoft Entra ID - Admin Portal (single-tenant, your org only)
AZURE_ADMIN_TENANT_ID = os.getenv("AZURE_ADMIN_TENANT_ID", "")
AZURE_ADMIN_CLIENT_ID = os.getenv("AZURE_ADMIN_CLIENT_ID", "")

# Microsoft Entra ID - Parent Portal (multi-tenant + personal accounts)
AZURE_CLIENT_ID = os.getenv("AZURE_CLIENT_ID", "")

# JWKS URLs
AZURE_ADMIN_JWKS_URL = f"https://login.microsoftonline.com/{AZURE_ADMIN_TENANT_ID}/discovery/v2.0/keys"
AZURE_COMMON_JWKS_URL = "https://login.microsoftonline.com/common/discovery/v2.0/keys"

# Google OAuth config
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"

# Apple Sign-In config
APPLE_CLIENT_ID = os.getenv("APPLE_CLIENT_ID", "")
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

# Cache for public keys
_jwks_cache: dict = {}


# MARK: - Schemas

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    role: str
    provider: Optional[str] = None
    phoneVerified: bool = False
    createdAt: datetime | None = None

    class Config:
        from_attributes = True


class MeResponse(BaseModel):
    user: UserResponse


class TokenValidateRequest(BaseModel):
    token: str
    provider: str  # "microsoft", "microsoft-admin", "google", or "apple"


class TokenValidateResponse(BaseModel):
    user: UserResponse
    needsPhoneVerification: bool


# MARK: - JWKS Fetching

async def get_jwks(url: str) -> dict:
    """Fetch public keys for token validation"""
    global _jwks_cache

    if url not in _jwks_cache:
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            _jwks_cache[url] = response.json()

    return _jwks_cache[url]


# MARK: - Token Validation

async def validate_microsoft_token(token: str, is_admin: bool = False) -> dict:
    """Validate a Microsoft OAuth token"""
    try:
        if is_admin:
            # Admin portal - single-tenant
            jwks_url = AZURE_ADMIN_JWKS_URL
            audience = AZURE_ADMIN_CLIENT_ID
            expected_issuer = f"https://login.microsoftonline.com/{AZURE_ADMIN_TENANT_ID}/v2.0"
        else:
            # Parent portal - multi-tenant
            jwks_url = AZURE_COMMON_JWKS_URL
            audience = AZURE_CLIENT_ID
            expected_issuer = None  # Any tenant is valid

        jwks = await get_jwks(jwks_url)

        # Decode header to get key ID
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        # Find the matching key
        rsa_key = None
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                rsa_key = key
                break

        if not rsa_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unable to find appropriate key"
            )

        # Decode options
        options = {"verify_aud": True}
        if expected_issuer is None:
            # For multi-tenant, skip issuer validation
            options["verify_iss"] = False

        # Validate token
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=["RS256"],
            audience=audience,
            issuer=expected_issuer,
            options=options
        )

        return payload

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Microsoft token: {str(e)}"
        )


async def validate_google_token(token: str) -> dict:
    """Validate a Google OAuth access token by calling userinfo API"""
    try:
        async with httpx.AsyncClient() as client:
            # Use the access token to get user info from Google
            response = await client.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {token}"}
            )

            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid Google token"
                )

            return response.json()

    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Failed to validate Google token: {str(e)}"
        )


async def validate_apple_token(token: str) -> dict:
    """Validate an Apple Sign-In token"""
    try:
        jwks = await get_jwks(APPLE_JWKS_URL)

        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        rsa_key = None
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                rsa_key = key
                break

        if not rsa_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unable to find appropriate key"
            )

        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=["RS256"],
            audience=APPLE_CLIENT_ID,
            issuer="https://appleid.apple.com"
        )

        return payload

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Apple token: {str(e)}"
        )


async def validate_oauth_token(token: str, provider: str) -> dict:
    """Validate an OAuth token based on provider"""
    if provider == "microsoft-admin":
        return await validate_microsoft_token(token, is_admin=True)
    elif provider == "microsoft":
        return await validate_microsoft_token(token, is_admin=False)
    elif provider == "google":
        return await validate_google_token(token)
    elif provider == "apple":
        return await validate_apple_token(token)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")


def extract_user_info(claims: dict, provider: str) -> tuple[str, str]:
    """Extract email and name from OAuth claims"""
    if provider in ["microsoft", "microsoft-admin"]:
        email = claims.get("preferred_username") or claims.get("email")
        name = claims.get("name", email)
    elif provider == "google":
        email = claims.get("email")
        name = claims.get("name", email)
    elif provider == "apple":
        email = claims.get("email")
        name = email  # Apple only gives name on first sign-in
    else:
        email = claims.get("email")
        name = claims.get("name", email)

    return email, name


# MARK: - Auth Dependency

async def get_current_user(
    authorization: str = Header(None),
    x_auth_provider: str = Header(None, alias="X-Auth-Provider"),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get or create user from OAuth token"""

    # Dev mode - return test admin user
    if DEV_MODE:
        result = await db.execute(select(User).where(User.email == "dev@test.local"))
        user = result.scalar_one_or_none()
        if not user:
            user = User(
                id=str(uuid.uuid4()),
                email="dev@test.local",
                name="Dev Admin",
                password_hash="",
                role="admin",
                provider="dev",
                phone_verified=True
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
        return user

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )

    token = authorization.replace("Bearer ", "")
    provider = x_auth_provider or "microsoft"

    claims = await validate_oauth_token(token, provider)
    email, name = extract_user_info(claims, provider)

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email not found in token"
        )

    # Find or create user
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        # Determine role - master admin or admin portal users get admin role
        is_master = email == MASTER_ADMIN_EMAIL
        is_admin_portal = provider == "microsoft-admin"
        role = "admin" if (is_master or is_admin_portal) else "user"

        user = User(
            id=str(uuid.uuid4()),
            email=email,
            name=name,
            password_hash="",
            role=role,
            provider=provider,
            phone_verified=is_admin_portal  # Admin portal users skip phone verification
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    """Require admin role"""
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return user


async def require_master_admin(user: User = Depends(get_current_user)) -> User:
    """Require master admin (you)"""
    if user.email != MASTER_ADMIN_EMAIL and user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Master admin access required"
        )
    return user


# MARK: - Routes

@router.get("/me", response_model=MeResponse)
async def get_me(user: User = Depends(get_current_user)):
    """Get current authenticated user"""
    return MeResponse(
        user=UserResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            role=user.role,
            provider=user.provider,
            phoneVerified=user.phone_verified,
            createdAt=user.created_at
        )
    )


@router.post("/validate", response_model=TokenValidateResponse)
async def validate_token(
    request: TokenValidateRequest,
    db: AsyncSession = Depends(get_db)
):
    """Validate OAuth token and return user info (used by frontend)"""
    claims = await validate_oauth_token(request.token, request.provider)
    email, name = extract_user_info(claims, request.provider)

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email not found in token"
        )

    # Find or create user
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        is_master = email == MASTER_ADMIN_EMAIL
        is_admin_portal = request.provider == "microsoft-admin"
        role = "admin" if (is_master or is_admin_portal) else "user"

        user = User(
            id=str(uuid.uuid4()),
            email=email,
            name=name,
            password_hash="",
            role=role,
            provider=request.provider,
            phone_verified=is_admin_portal
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    # Check if phone verification is needed (for non-admin-portal users)
    needs_verification = not user.phone_verified and request.provider != "microsoft-admin"

    return TokenValidateResponse(
        user=UserResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            role=user.role,
            provider=user.provider,
            phoneVerified=user.phone_verified,
            createdAt=user.created_at
        ),
        needsPhoneVerification=needs_verification
    )


@router.post("/make-admin/{user_id}")
async def make_admin(
    user_id: str,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Promote a user to admin (admin only)"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.role = "admin"
    await db.commit()

    return {"message": f"{user.email} is now an admin"}
