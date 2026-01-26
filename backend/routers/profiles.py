"""
Restriction profile routes
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from datetime import datetime
import uuid

from database import get_db, RestrictionProfile, Device, User
from routers.auth import get_current_user, require_admin

router = APIRouter()


# MARK: - Schemas

class ProfileResponse(BaseModel):
    id: str
    name: str
    description: str
    allowPhone: bool
    allowMessages: bool
    allowContacts: bool
    allowCamera: bool
    allowPhotos: bool
    deviceCount: int = 0

    class Config:
        from_attributes = True


class CreateProfileRequest(BaseModel):
    name: str
    description: str = ""
    allowPhone: bool = True
    allowMessages: bool = True
    allowContacts: bool = True
    allowCamera: bool = False
    allowPhotos: bool = False


class AssignProfileRequest(BaseModel):
    deviceId: str


# MARK: - Routes

@router.get("", response_model=list[ProfileResponse])
async def list_profiles(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all restriction profiles"""
    result = await db.execute(select(RestrictionProfile))
    profiles = result.scalars().all()

    responses = []
    for profile in profiles:
        # Count devices using this profile
        count_result = await db.execute(
            select(func.count()).where(Device.profile_id == profile.id)
        )
        device_count = count_result.scalar() or 0

        responses.append(ProfileResponse(
            id=profile.id,
            name=profile.name,
            description=profile.description,
            allowPhone=profile.allow_phone,
            allowMessages=profile.allow_messages,
            allowContacts=profile.allow_contacts,
            allowCamera=profile.allow_camera,
            allowPhotos=profile.allow_photos,
            deviceCount=device_count
        ))

    return responses


@router.post("", response_model=ProfileResponse)
async def create_profile(
    request: CreateProfileRequest,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new restriction profile (admin only)"""
    profile = RestrictionProfile(
        id=str(uuid.uuid4()),
        name=request.name,
        description=request.description,
        allow_phone=request.allowPhone,
        allow_messages=request.allowMessages,
        allow_contacts=request.allowContacts,
        allow_camera=request.allowCamera,
        allow_photos=request.allowPhotos
    )

    db.add(profile)
    await db.commit()
    await db.refresh(profile)

    return ProfileResponse(
        id=profile.id,
        name=profile.name,
        description=profile.description,
        allowPhone=profile.allow_phone,
        allowMessages=profile.allow_messages,
        allowContacts=profile.allow_contacts,
        allowCamera=profile.allow_camera,
        allowPhotos=profile.allow_photos,
        deviceCount=0
    )


@router.get("/{profile_id}", response_model=ProfileResponse)
async def get_profile(
    profile_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific profile"""
    result = await db.execute(
        select(RestrictionProfile).where(RestrictionProfile.id == profile_id)
    )
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    count_result = await db.execute(
        select(func.count()).where(Device.profile_id == profile.id)
    )
    device_count = count_result.scalar() or 0

    return ProfileResponse(
        id=profile.id,
        name=profile.name,
        description=profile.description,
        allowPhone=profile.allow_phone,
        allowMessages=profile.allow_messages,
        allowContacts=profile.allow_contacts,
        allowCamera=profile.allow_camera,
        allowPhotos=profile.allow_photos,
        deviceCount=device_count
    )


@router.post("/{profile_id}/assign")
async def assign_profile(
    profile_id: str,
    request: AssignProfileRequest,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Assign a profile to a device (admin only)"""
    # Get profile
    profile_result = await db.execute(
        select(RestrictionProfile).where(RestrictionProfile.id == profile_id)
    )
    profile = profile_result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Get device
    device_result = await db.execute(
        select(Device).where(Device.id == request.deviceId)
    )
    device = device_result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Assign profile
    device.profile_id = profile.id
    device.status = "managed"
    await db.commit()

    # TODO: Queue InstallProfile command via APNs

    return {"message": f"Profile '{profile.name}' assigned to device '{device.name}'"}


@router.delete("/{profile_id}")
async def delete_profile(
    profile_id: str,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a profile (admin only)"""
    result = await db.execute(
        select(RestrictionProfile).where(RestrictionProfile.id == profile_id)
    )
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Check if profile is in use
    count_result = await db.execute(
        select(func.count()).where(Device.profile_id == profile.id)
    )
    if count_result.scalar() > 0:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete profile that is assigned to devices"
        )

    await db.delete(profile)
    await db.commit()

    return {"message": "Profile deleted"}
