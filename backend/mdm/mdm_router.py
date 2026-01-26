"""
Apple MDM Protocol Implementation

Handles device enrollment, check-in, and command responses.
Reference: https://developer.apple.com/documentation/devicemanagement
"""

from fastapi import APIRouter, Request, Response, Depends, HTTPException
from fastapi.responses import PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import plistlib
import uuid
from datetime import datetime

from database import get_db, Device, EnrollmentToken, MDMCommand
from mdm.profile_builder import build_enrollment_profile, build_restriction_profile
from mdm.apns import send_push_notification

router = APIRouter()


# MARK: - Enrollment

@router.get("/enroll/{token}")
async def get_enrollment_profile(
    token: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Serve the MDM enrollment profile.
    Device visits this URL to download and install the profile.
    """
    # Validate token
    result = await db.execute(
        select(EnrollmentToken).where(EnrollmentToken.token == token)
    )
    enrollment_token = result.scalar_one_or_none()

    if not enrollment_token or not enrollment_token.is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    # Build enrollment profile
    profile_data = build_enrollment_profile()

    return Response(
        content=profile_data,
        media_type="application/x-apple-aspen-config",
        headers={
            "Content-Disposition": f'attachment; filename="enroll.mobileconfig"'
        }
    )


# MARK: - MDM Check-in Endpoint

@router.put("/checkin")
@router.post("/checkin")
async def mdm_checkin(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Handle MDM check-in messages from devices.

    Message types:
    - Authenticate: Initial enrollment authentication
    - TokenUpdate: Device provides its APNs push token
    - CheckOut: Device is removing MDM profile
    """
    body = await request.body()

    try:
        plist = plistlib.loads(body)
    except Exception as e:
        print(f"Failed to parse plist: {e}")
        raise HTTPException(status_code=400, detail="Invalid plist")

    message_type = plist.get("MessageType")
    udid = plist.get("UDID")

    print(f"MDM Check-in: {message_type} from {udid}")

    if message_type == "Authenticate":
        return await handle_authenticate(plist, db)

    elif message_type == "TokenUpdate":
        return await handle_token_update(plist, db)

    elif message_type == "CheckOut":
        return await handle_checkout(plist, db)

    else:
        print(f"Unknown message type: {message_type}")
        return Response(status_code=200)


async def handle_authenticate(plist: dict, db: AsyncSession) -> Response:
    """Handle initial enrollment authentication"""
    udid = plist.get("UDID")

    # Check if device already exists
    result = await db.execute(select(Device).where(Device.udid == udid))
    device = result.scalar_one_or_none()

    if not device:
        # Create new device record
        device = Device(
            id=str(uuid.uuid4()),
            udid=udid,
            name=f"Device-{udid[:8]}",
            status="pending"
        )
        db.add(device)
        await db.commit()

    # Return empty plist to accept enrollment
    return Response(
        content=plistlib.dumps({}),
        media_type="application/xml"
    )


async def handle_token_update(plist: dict, db: AsyncSession) -> Response:
    """Handle token update - device provides APNs push token"""
    udid = plist.get("UDID")
    push_magic = plist.get("PushMagic")
    token = plist.get("Token")  # This is bytes
    unlock_token = plist.get("UnlockToken")

    result = await db.execute(select(Device).where(Device.udid == udid))
    device = result.scalar_one_or_none()

    if device:
        device.push_magic = push_magic
        device.push_token = token.hex() if token else None
        device.unlock_token = unlock_token
        device.status = "enrolled"
        device.last_checkin = datetime.utcnow()
        await db.commit()

    return Response(
        content=plistlib.dumps({}),
        media_type="application/xml"
    )


async def handle_checkout(plist: dict, db: AsyncSession) -> Response:
    """Handle device checkout - MDM profile is being removed"""
    udid = plist.get("UDID")

    result = await db.execute(select(Device).where(Device.udid == udid))
    device = result.scalar_one_or_none()

    if device:
        device.status = "removed"
        device.push_token = None
        device.push_magic = None
        await db.commit()

    return Response(
        content=plistlib.dumps({}),
        media_type="application/xml"
    )


# MARK: - MDM Server Endpoint

@router.put("/mdm")
@router.post("/mdm")
async def mdm_server(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Handle MDM command responses from devices.

    When we push a notification, the device connects here
    to get commands or report command status.
    """
    body = await request.body()

    try:
        plist = plistlib.loads(body)
    except Exception as e:
        print(f"Failed to parse plist: {e}")
        raise HTTPException(status_code=400, detail="Invalid plist")

    status = plist.get("Status")
    udid = plist.get("UDID")
    command_uuid = plist.get("CommandUUID")

    print(f"MDM Server: status={status} udid={udid} cmd={command_uuid}")

    # Update device last check-in
    device_result = await db.execute(select(Device).where(Device.udid == udid))
    device = device_result.scalar_one_or_none()

    if device:
        device.last_checkin = datetime.utcnow()

    # Handle command response
    if command_uuid:
        cmd_result = await db.execute(
            select(MDMCommand).where(MDMCommand.command_uuid == command_uuid)
        )
        command = cmd_result.scalar_one_or_none()

        if command:
            if status == "Acknowledged":
                command.status = "acknowledged"
                command.acknowledged_at = datetime.utcnow()
            elif status == "Error":
                command.status = "failed"
                error_chain = plist.get("ErrorChain", [])
                if error_chain:
                    command.error_message = str(error_chain[0])
            elif status == "NotNow":
                # Device is busy, will retry later
                command.status = "pending"

    await db.commit()

    # Check for pending commands
    if device and status in ("Idle", "Acknowledged"):
        pending = await db.execute(
            select(MDMCommand)
            .where(MDMCommand.device_id == device.id)
            .where(MDMCommand.status == "pending")
            .order_by(MDMCommand.created_at)
            .limit(1)
        )
        next_command = pending.scalar_one_or_none()

        if next_command and next_command.payload:
            # Send the next command
            next_command.status = "sent"
            next_command.sent_at = datetime.utcnow()
            await db.commit()

            return Response(
                content=next_command.payload,
                media_type="application/xml"
            )

    # No commands - return empty response
    return Response(
        content=plistlib.dumps({}),
        media_type="application/xml"
    )
