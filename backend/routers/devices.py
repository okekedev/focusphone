"""
Device management routes
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from datetime import datetime

from database import get_db, Device, User
from routers.auth import get_current_user, require_admin

router = APIRouter()


# MARK: - Schemas

class DeviceResponse(BaseModel):
    id: str
    udid: str
    name: str
    model: str
    osVersion: str
    serialNumber: str | None = None
    status: str
    profileId: str | None = None
    lastCheckin: datetime | None = None
    batteryLevel: float | None = None
    latitude: float | None = None
    longitude: float | None = None
    locationUpdatedAt: datetime | None = None
    ownerId: str | None = None

    class Config:
        from_attributes = True

    @classmethod
    def from_device(cls, device: Device) -> "DeviceResponse":
        return cls(
            id=device.id,
            udid=device.udid,
            name=device.name,
            model=device.model,
            osVersion=device.os_version,
            serialNumber=device.serial_number or None,
            status=device.status,
            profileId=device.profile_id,
            lastCheckin=device.last_checkin,
            batteryLevel=device.battery_level,
            latitude=device.latitude,
            longitude=device.longitude,
            locationUpdatedAt=device.location_updated_at,
            ownerId=device.owner_id
        )


class DeviceReportRequest(BaseModel):
    """Request body for device status reporting"""
    batteryLevel: float | None = None
    latitude: float | None = None
    longitude: float | None = None


# MARK: - Routes

@router.get("", response_model=list[DeviceResponse])
async def list_devices(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List devices for current user (or all if admin)"""
    if user.role == "admin":
        result = await db.execute(select(Device))
    else:
        result = await db.execute(
            select(Device).where(Device.owner_id == user.id)
        )

    devices = result.scalars().all()
    return [DeviceResponse.from_device(d) for d in devices]


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific device"""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Check ownership unless admin
    if user.role != "admin" and device.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    return DeviceResponse.from_device(device)


@router.post("/{device_id}/unenroll")
async def unenroll_device(
    device_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Request device unenrollment"""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Check ownership unless admin
    if user.role != "admin" and device.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    device.status = "unenrolling"
    await db.commit()

    # TODO: Queue RemoveProfile command via APNs

    return {"message": "Unenrollment requested", "deviceId": device.id}


@router.delete("/{device_id}")
async def delete_device(
    device_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a device (owner or admin)"""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Check ownership unless admin
    if user.role != "admin" and device.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    await db.delete(device)
    await db.commit()

    return {"message": "Device deleted"}


@router.post("/{device_id}/report")
async def report_device_status(
    device_id: str,
    report: DeviceReportRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Device reports its current status (battery, location).
    This endpoint is called by the device itself during check-ins.
    """
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Update battery level
    if report.batteryLevel is not None:
        device.battery_level = report.batteryLevel

    # Update location
    if report.latitude is not None and report.longitude is not None:
        device.latitude = report.latitude
        device.longitude = report.longitude
        device.location_updated_at = datetime.utcnow()

    # Update last check-in
    device.last_checkin = datetime.utcnow()

    await db.commit()

    return {"message": "Status updated", "deviceId": device.id}


@router.post("/report-by-udid/{udid}")
async def report_device_status_by_udid(
    udid: str,
    report: DeviceReportRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Device reports its current status using UDID.
    This is useful when device doesn't know its internal ID.
    """
    result = await db.execute(select(Device).where(Device.udid == udid))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    # Update battery level
    if report.batteryLevel is not None:
        device.battery_level = report.batteryLevel

    # Update location
    if report.latitude is not None and report.longitude is not None:
        device.latitude = report.latitude
        device.longitude = report.longitude
        device.location_updated_at = datetime.utcnow()

    # Update last check-in
    device.last_checkin = datetime.utcnow()

    await db.commit()

    return {"message": "Status updated", "deviceId": device.id}
