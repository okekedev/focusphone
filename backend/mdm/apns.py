"""
Apple Push Notification Service (APNs) for MDM

Sends push notifications to devices to trigger MDM check-in.
Uses certificate-based authentication (required for MDM).
"""

import os
import ssl
import base64
import tempfile
from pathlib import Path
from httpx import AsyncClient
from typing import Optional

# Certificate paths (relative to backend/certs/)
CERTS_DIR = Path(__file__).parent.parent / "certs"

# MDM Topic - extracted from the push certificate
# Format: com.apple.mgmt.External.<uuid>
MDM_TOPIC = os.getenv("MDM_TOPIC", "com.apple.mgmt.External.461f409a-d81a-4b5e-a009-3fb8f607aadc")

# Use production or sandbox APNs
APNS_PRODUCTION = os.getenv("APNS_PRODUCTION", "true").lower() == "true"
APNS_HOST = "api.push.apple.com" if APNS_PRODUCTION else "api.sandbox.push.apple.com"

# Temp file paths for decoded certificates
_temp_cert_path: Optional[str] = None
_temp_key_path: Optional[str] = None


def _get_cert_paths() -> tuple[str, str]:
    """
    Get paths to MDM push certificate and key.

    Supports three modes:
    1. Base64-encoded env vars (MDM_PUSH_CERT_B64, MDM_PUSH_KEY_B64) - for cloud deployment
    2. File path env vars (MDM_PUSH_CERT, MDM_PUSH_KEY) - for custom paths
    3. Default local paths (backend/certs/) - for local development
    """
    global _temp_cert_path, _temp_key_path

    # Check for base64-encoded certificates in env vars
    cert_b64 = os.getenv("MDM_PUSH_CERT_B64")
    key_b64 = os.getenv("MDM_PUSH_KEY_B64")

    if cert_b64 and key_b64:
        # Decode and write to temp files (only once)
        if not _temp_cert_path or not _temp_key_path:
            # Create temp directory for certs
            temp_dir = tempfile.mkdtemp(prefix="mdm_certs_")

            _temp_cert_path = os.path.join(temp_dir, "mdm_push_cert.pem")
            _temp_key_path = os.path.join(temp_dir, "mdm_push_key.pem")

            # Decode and write cert
            cert_data = base64.b64decode(cert_b64)
            with open(_temp_cert_path, "wb") as f:
                f.write(cert_data)

            # Decode and write key
            key_data = base64.b64decode(key_b64)
            with open(_temp_key_path, "wb") as f:
                f.write(key_data)

            # Set permissions
            os.chmod(_temp_key_path, 0o600)

            print(f"MDM certificates decoded from environment variables")

        return _temp_cert_path, _temp_key_path

    # Check for file path env vars
    cert_path = os.getenv("MDM_PUSH_CERT")
    key_path = os.getenv("MDM_PUSH_KEY")

    if cert_path and key_path:
        return cert_path, key_path

    # Default to local paths
    return str(CERTS_DIR / "mdm_push_cert.pem"), str(CERTS_DIR / "mdm_push_key.pem")


def get_ssl_context() -> ssl.SSLContext:
    """Create SSL context with MDM push certificate"""
    cert_path, key_path = _get_cert_paths()

    ctx = ssl.create_default_context()
    ctx.load_cert_chain(
        certfile=cert_path,
        keyfile=key_path
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

    cert_path, key_path = _get_cert_paths()

    # Check certificate files exist
    if not os.path.exists(cert_path):
        print(f"MDM push certificate not found: {cert_path}")
        return False
    if not os.path.exists(key_path):
        print(f"MDM push key not found: {key_path}")
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
