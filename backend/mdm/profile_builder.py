"""
MDM Profile Builder

Builds configuration profiles for device enrollment and restrictions.
"""

import plistlib
import uuid
import os

# Organization settings
ORG_NAME = os.getenv("MDM_ORG_NAME", "FocusPhone")
ORG_IDENTIFIER = os.getenv("MDM_ORG_IDENTIFIER", "com.focusphone")
SERVER_URL = os.getenv("MDM_SERVER_URL", "https://your-mdm-server.com")
TOPIC = os.getenv("MDM_TOPIC", "com.apple.mgmt.External.461f409a-d81a-4b5e-a009-3fb8f607aadc")


def build_enrollment_profile() -> bytes:
    """
    Build the MDM enrollment profile.

    This profile tells the device how to connect to the MDM server.
    """
    profile_uuid = str(uuid.uuid4()).upper()
    mdm_payload_uuid = str(uuid.uuid4()).upper()
    scep_payload_uuid = str(uuid.uuid4()).upper()

    # MDM payload - configures MDM connection
    mdm_payload = {
        "PayloadType": "com.apple.mdm",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{ORG_IDENTIFIER}.mdm",
        "PayloadUUID": mdm_payload_uuid,
        "PayloadDisplayName": "MDM Profile",

        "Topic": TOPIC,
        "ServerURL": f"{SERVER_URL}/mdm",
        "CheckInURL": f"{SERVER_URL}/checkin",
        "ServerCapabilities": ["com.apple.mdm.per-user-connections"],
        "AccessRights": 8191,  # Full access
        "CheckOutWhenRemoved": True,
        "SignMessage": False,  # Set True if signing payloads
        "UseDevelopmentAPNS": False,
    }

    # Main profile
    profile = {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{ORG_IDENTIFIER}.enrollment",
        "PayloadUUID": profile_uuid,
        "PayloadDisplayName": f"{ORG_NAME} Device Management",
        "PayloadDescription": "This profile will enroll your device for management.",
        "PayloadOrganization": ORG_NAME,
        "PayloadRemovalDisallowed": False,  # User can remove enrollment
        "PayloadContent": [mdm_payload],
    }

    return plistlib.dumps(profile)


def build_restriction_profile(
    name: str,
    description: str,
    allowed_bundle_ids: list[str]
) -> bytes:
    """
    Build a restriction profile that limits the device to specific apps.

    Args:
        name: Display name for the profile
        description: Description shown to user
        allowed_bundle_ids: List of app bundle IDs to allow
    """
    profile_uuid = str(uuid.uuid4()).upper()
    restriction_payload_uuid = str(uuid.uuid4()).upper()

    # Restriction payload
    restriction_payload = {
        "PayloadType": "com.apple.applicationaccess",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{ORG_IDENTIFIER}.restriction",
        "PayloadUUID": restriction_payload_uuid,
        "PayloadDisplayName": "App Restrictions",

        # Only allow these apps
        "allowListedAppBundleIDs": allowed_bundle_ids,

        # Disable everything else
        "allowAppInstallation": False,
        "allowAppRemoval": False,
        "allowInAppPurchases": False,
        "allowSafari": False,
        "allowCamera": "com.apple.camera" in allowed_bundle_ids,
        "allowVideoConferencing": False,
        "allowExplicitContent": False,
        "allowGameCenter": False,
        "allowMultiplayerGaming": False,
        "allowAddingGameCenterFriends": False,
        "allowYouTube": False,
        "allowiTunes": False,
        "allowBookstore": False,
        "allowPodcasts": False,
        "allowNews": False,
        "allowMusicService": False,
        "allowRadioService": False,
        "allowUIConfigurationProfileInstallation": False,
        "allowEnterpriseAppTrust": False,
        "allowVPNCreation": False,
        "allowGlobalBackgroundFetchWhenRoaming": False,
        "allowEraseContentAndSettings": False,  # Prevent factory reset
        "allowEnablingRestrictions": False,
        "allowFilesNetworkDriveAccess": False,
        "allowFilesUSBDriveAccess": False,
    }

    # Main profile
    profile = {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{ORG_IDENTIFIER}.restriction.{profile_uuid[:8]}",
        "PayloadUUID": profile_uuid,
        "PayloadDisplayName": name,
        "PayloadDescription": description,
        "PayloadOrganization": ORG_NAME,
        "PayloadRemovalDisallowed": True,  # Can't remove restriction profile
        "PayloadContent": [restriction_payload],
    }

    return plistlib.dumps(profile)


def build_install_profile_command(
    command_uuid: str,
    profile_data: bytes
) -> bytes:
    """Build an InstallProfile MDM command"""
    command = {
        "CommandUUID": command_uuid,
        "Command": {
            "RequestType": "InstallProfile",
            "Payload": profile_data,
        }
    }
    return plistlib.dumps(command)


def build_remove_profile_command(
    command_uuid: str,
    profile_identifier: str
) -> bytes:
    """Build a RemoveProfile MDM command"""
    command = {
        "CommandUUID": command_uuid,
        "Command": {
            "RequestType": "RemoveProfile",
            "Identifier": profile_identifier,
        }
    }
    return plistlib.dumps(command)


def build_device_info_command(command_uuid: str) -> bytes:
    """Build a DeviceInformation MDM command"""
    command = {
        "CommandUUID": command_uuid,
        "Command": {
            "RequestType": "DeviceInformation",
            "Queries": [
                "DeviceName",
                "OSVersion",
                "BuildVersion",
                "ModelName",
                "Model",
                "ProductName",
                "SerialNumber",
                "UDID",
                "BatteryLevel",
                "IsSupervised",
            ]
        }
    }
    return plistlib.dumps(command)
