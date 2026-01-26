"""
Apple Push Notification Service (APNs) for MDM

Sends push notifications to devices to trigger MDM check-in.
Uses certificate-based authentication (required for MDM).
"""

import os
import ssl
from pathlib import Path
from httpx import AsyncClient
from typing import Optional

# Certificate paths (relative to backend/certs/)
CERTS_DIR = Path(__file__).parent.parent / "certs"
MDM_PUSH_CERT = os.getenv("MDM_PUSH_CERT", str(CERTS_DIR / "mdm_push_cert.pem"))
MDM_PUSH_KEY = os.getenv("MDM_PUSH_KEY", str(CERTS_DIR / "mdm_push_key.pem"))

# MDM Topic - extracted from the push certificate
# Format: com.apple.mgmt.External.<uuid>
MDM_TOPIC = os.getenv("MDM_TOPIC", "com.apple.mgmt.External.461f409a-d81a-4b5e-a009-3fb8f607aadc")

# Use production or sandbox APNs
APNS_PRODUCTION = os.getenv("APNS_PRODUCTION", "true").lower() == "true"
APNS_HOST = "api.push.apple.com" if APNS_PRODUCTION else "api.sandbox.push.apple.com"


def get_ssl_context() -> ssl.SSLContext:
    """Create SSL context with MDM push certificate"""
    ctx = ssl.create_default_context()
    ctx.load_cert_chain(
        certfile=MDM_PUSH_CERT,
        keyfile=MDM_PUSH_KEY
    )
    return ctx


async def send_push_notification(
    push_token: str,
    push_magic: str
) -> bool:
    """
    Send MDM push notification to a device.

    This triggers the device to check in with the MDM server.

    Args:
        push_token: Device's APNs push token (hex string)
        push_magic: Device's push magic string

    Returns:
        True if successful, False otherwise
    """
    if not push_token or not push_magic:
        print("Missing push token or push magic")
        return False

    # Check certificate files exist
    if not os.path.exists(MDM_PUSH_CERT):
        print(f"MDM push certificate not found: {MDM_PUSH_CERT}")
        return False
    if not os.path.exists(MDM_PUSH_KEY):
        print(f"MDM push key not found: {MDM_PUSH_KEY}")
        return False

    # MDM push payload - just contains the push magic
    payload = {
        "mdm": push_magic
    }

    url = f"https://{APNS_HOST}/3/device/{push_token}"

    headers = {
        "apns-topic": MDM_TOPIC,
        "apns-push-type": "mdm",
        "apns-priority": "10",
        "apns-expiration": "0",
    }

    try:
        ssl_context = get_ssl_context()

        async with AsyncClient(http2=True, verify=ssl_context) as client:
            response = await client.post(
                url,
                headers=headers,
                json=payload,
            )

            if response.status_code == 200:
                print(f"Push notification sent successfully to {push_token[:16]}...")
                return True
            else:
                print(f"Push notification failed: {response.status_code} {response.text}")
                return False

    except Exception as e:
        print(f"Push notification error: {e}")
        return False


async def send_push_to_device(device) -> bool:
    """
    Convenience function to send push to a Device model instance.
    """
    if not device.push_token or not device.push_magic:
        return False

    return await send_push_notification(device.push_token, device.push_magic)
