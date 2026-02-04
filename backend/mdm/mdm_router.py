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

from database import get_db, Device, EnrollmentToken, MDMCommand, RestrictionProfile
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

    # Mark token as accessed (for linking during Authenticate)
    enrollment_token.last_accessed_at = datetime.utcnow()
    await db.commit()

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

    # Find the most recently accessed unused enrollment token
    # This links the device to the user who created the enrollment token
    from datetime import timedelta
    cutoff = datetime.utcnow() - timedelta(hours=1)  # Token must have been accessed within last hour
    token_result = await db.execute(
        select(EnrollmentToken)
        .where(EnrollmentToken.is_used == False)
        .where(EnrollmentToken.last_accessed_at != None)
        .where(EnrollmentToken.last_accessed_at >= cutoff)
        .where(EnrollmentToken.device_udid == None)  # Not yet linked to a device
        .order_by(EnrollmentToken.last_accessed_at.desc())
        .limit(1)
    )
    enrollment_token = token_result.scalar_one_or_none()

    if not device:
        # Create new device record
        device = Device(
            id=str(uuid.uuid4()),
            udid=udid,
            name=f"Device-{udid[:8]}",
            status="pending"
        )
        # Link to owner if we found an enrollment token
        if enrollment_token:
            device.owner_id = enrollment_token.owner_id
            device.profile_id = enrollment_token.profile_id
        db.add(device)
    else:
        # Update existing device ownership if we have a new enrollment token
        if enrollment_token:
            device.owner_id = enrollment_token.owner_id
            device.profile_id = enrollment_token.profile_id
            device.status = "pending"

    # Link enrollment token to this device
    if enrollment_token:
        enrollment_token.device_udid = udid
        print(f"Linked device {udid} to enrollment token {enrollment_token.id} (owner: {enrollment_token.owner_id})")

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

        # Find and mark the enrollment token as used
        token_result = await db.execute(
            select(EnrollmentToken)
            .where(EnrollmentToken.device_udid == udid)
            .where(EnrollmentToken.is_used == False)
        )
        enrollment_token = token_result.scalar_one_or_none()

        if enrollment_token:
            enrollment_token.is_used = True
            enrollment_token.used_at = datetime.utcnow()
            await db.commit()
            print(f"Marked enrollment token {enrollment_token.id} as used")

            # If the token has a profile, queue the restriction profile installation
            if enrollment_token.profile_id:
                profile_result = await db.execute(
                    select(RestrictionProfile).where(RestrictionProfile.id == enrollment_token.profile_id)
                )
                profile = profile_result.scalar_one_or_none()

                if profile:
                    await queue_restriction_profile(device, profile, db)
                    print(f"Queued restriction profile '{profile.name}' for device {udid}")

    return Response(
        content=plistlib.dumps({}),
        media_type="application/xml"
    )


async def queue_restriction_profile(device: Device, profile: RestrictionProfile, db: AsyncSession):
    """Queue an InstallProfile command to apply the restriction profile to the device"""
    from mdm.profile_builder import build_restriction_profile, build_install_profile_command

    # Build the restriction profile
    restriction_profile_data = build_restriction_profile(
        name=profile.name,
        description=profile.description or f"Managed by {profile.name}",
        allowed_bundle_ids=profile.allowed_bundle_ids
    )

    # Build the MDM command
    command_uuid = str(uuid.uuid4()).upper()
    command_payload = build_install_profile_command(command_uuid, restriction_profile_data)

    # Create command record
    command = MDMCommand(
        id=str(uuid.uuid4()),
        command_uuid=command_uuid,
        command_type="InstallProfile",
        payload=command_payload,
        status="pending",
        device_id=device.id
    )
    db.add(command)
    await db.commit()

    # Send APNs push to wake the device
    if device.push_token and device.push_magic:
        try:
            await send_push_notification(device.push_token, device.push_magic)
            print(f"Sent APNs push to device {device.udid}")
        except Exception as e:
            print(f"Failed to send APNs push: {e}")


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
