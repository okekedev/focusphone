import Foundation

// MARK: - MDM Protocol
// Apple MDM Protocol implementation
// Reference: https://developer.apple.com/documentation/devicemanagement

/// MDM message types for device communication
enum MDMMessageType: String {
    case authenticate = "Authenticate"
    case tokenUpdate = "TokenUpdate"
    case checkOut = "CheckOut"
    case idle = "Idle"
    case acknowledged = "Acknowledged"
    case notNow = "NotNow"
    case error = "Error"
}

/// MDM commands that can be sent to devices
enum MDMCommandType: String, Codable {
    // Profile Management
    case installProfile = "InstallProfile"
    case removeProfile = "RemoveProfile"

    // Device Information
    case deviceInformation = "DeviceInformation"
    case securityInfo = "SecurityInfo"
    case installedApplicationList = "InstalledApplicationList"

    // Restrictions
    case restrictions = "Restrictions"

    // Device Actions
    case deviceLock = "DeviceLock"
    case eraseDevice = "EraseDevice"
    case clearPasscode = "ClearPasscode"
    case restartDevice = "RestartDevice"
    case shutDownDevice = "ShutDownDevice"
}

// MARK: - MDM Plist Structures

/// Check-in message from device during enrollment
struct MDMCheckinMessage: Codable {
    let messageType: String
    let topic: String?
    let udid: String?
    let pushMagic: String?
    let token: Data?
    let unlockToken: Data?

    enum CodingKeys: String, CodingKey {
        case messageType = "MessageType"
        case topic = "Topic"
        case udid = "UDID"
        case pushMagic = "PushMagic"
        case token = "Token"
        case unlockToken = "UnlockToken"
    }
}

/// Response from device after command execution
struct MDMCommandResponse: Codable {
    let status: String
    let udid: String
    let commandUUID: String?
    let errorChain: [MDMErrorInfo]?

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case udid = "UDID"
        case commandUUID = "CommandUUID"
        case errorChain = "ErrorChain"
    }
}

struct MDMErrorInfo: Codable {
    let errorCode: Int
    let errorDomain: String
    let localizedDescription: String?

    enum CodingKeys: String, CodingKey {
        case errorCode = "ErrorCode"
        case errorDomain = "ErrorDomain"
        case localizedDescription = "LocalizedDescription"
    }
}

// MARK: - MDM Command Builder

struct MDMCommandBuilder {

    /// Build InstallProfile command with restriction payload
    static func buildInstallProfileCommand(
        commandUUID: UUID,
        profileData: Data
    ) -> [String: Any] {
        return [
            "CommandUUID": commandUUID.uuidString,
            "Command": [
                "RequestType": MDMCommandType.installProfile.rawValue,
                "Payload": profileData
            ]
        ]
    }

    /// Build DeviceInformation query command
    static func buildDeviceInfoCommand(commandUUID: UUID) -> [String: Any] {
        return [
            "CommandUUID": commandUUID.uuidString,
            "Command": [
                "RequestType": MDMCommandType.deviceInformation.rawValue,
                "Queries": [
                    "DeviceName",
                    "OSVersion",
                    "BuildVersion",
                    "ModelName",
                    "Model",
                    "ProductName",
                    "SerialNumber",
                    "UDID",
                    "WiFiMAC",
                    "BluetoothMAC",
                    "BatteryLevel",
                    "IsSupervised"
                ]
            ]
        ]
    }

    /// Build RemoveProfile command
    static func buildRemoveProfileCommand(
        commandUUID: UUID,
        profileIdentifier: String
    ) -> [String: Any] {
        return [
            "CommandUUID": commandUUID.uuidString,
            "Command": [
                "RequestType": MDMCommandType.removeProfile.rawValue,
                "Identifier": profileIdentifier
            ]
        ]
    }

    /// Build DeviceLock command
    static func buildDeviceLockCommand(
        commandUUID: UUID,
        message: String? = nil,
        phoneNumber: String? = nil
    ) -> [String: Any] {
        var command: [String: Any] = [
            "RequestType": MDMCommandType.deviceLock.rawValue
        ]
        if let message = message {
            command["Message"] = message
        }
        if let phone = phoneNumber {
            command["PhoneNumber"] = phone
        }
        return [
            "CommandUUID": commandUUID.uuidString,
            "Command": command
        ]
    }
}

// MARK: - Profile Builder

struct MDMProfileBuilder {

    /// Organization identifier for profiles
    static let organizationIdentifier = "com.yourdomain.mdm"

    /// Build a restriction profile that only allows specified apps
    static func buildRestrictionProfile(
        displayName: String,
        description: String,
        allowedBundleIDs: [String],
        uuid: UUID = UUID()
    ) -> Data? {
        let profileUUID = uuid.uuidString
        let payloadUUID = UUID().uuidString

        let restrictionPayload: [String: Any] = [
            "PayloadType": "com.apple.applicationaccess",
            "PayloadVersion": 1,
            "PayloadIdentifier": "\(organizationIdentifier).restriction.\(payloadUUID)",
            "PayloadUUID": payloadUUID,
            "PayloadDisplayName": "App Restrictions",

            // Restrict to allowlisted apps only
            "allowListedAppBundleIDs": allowedBundleIDs,

            // Disable various features
            "allowAppInstallation": false,
            "allowAppRemoval": false,
            "allowInAppPurchases": false,
            "allowSafari": false,
            "allowCamera": allowedBundleIDs.contains("com.apple.camera"),
            "allowExplicitContent": false,
            "allowGameCenter": false,
            "allowMultiplayerGaming": false,
            "allowAddingGameCenterFriends": false,
            "allowYouTube": false,
            "allowiTunes": false,
            "allowBookstore": false,
            "allowPodcasts": false,
            "allowNews": false,
            "allowMusicService": false,
            "allowUIConfigurationProfileInstallation": false,
            "allowEnterpriseAppTrust": false,
            "allowVPNCreation": false
        ]

        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": "\(organizationIdentifier).profile.\(profileUUID)",
            "PayloadUUID": profileUUID,
            "PayloadDisplayName": displayName,
            "PayloadDescription": description,
            "PayloadOrganization": "Your Organization",
            "PayloadRemovalDisallowed": true,  // Prevent user from removing
            "PayloadContent": [restrictionPayload]
        ]

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: profile,
                format: .xml,
                options: 0
            )
            return data
        } catch {
            print("Failed to build profile: \(error)")
            return nil
        }
    }

    /// Build MDM enrollment profile
    static func buildEnrollmentProfile(
        serverURL: String,
        topic: String,
        identityCertificateUUID: String,
        uuid: UUID = UUID()
    ) -> Data? {
        let profileUUID = uuid.uuidString
        let mdmPayloadUUID = UUID().uuidString

        let mdmPayload: [String: Any] = [
            "PayloadType": "com.apple.mdm",
            "PayloadVersion": 1,
            "PayloadIdentifier": "\(organizationIdentifier).mdm.\(mdmPayloadUUID)",
            "PayloadUUID": mdmPayloadUUID,
            "PayloadDisplayName": "MDM Profile",

            "IdentityCertificateUUID": identityCertificateUUID,
            "Topic": topic,
            "ServerURL": serverURL,
            "ServerCapabilities": ["com.apple.mdm.per-user-connections"],
            "CheckInURL": "\(serverURL)/checkin",
            "CheckOutWhenRemoved": true,
            "AccessRights": 8191,  // Full access
            "SignMessage": true,
            "UseDevelopmentAPNS": false
        ]

        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": "\(organizationIdentifier).enrollment.\(profileUUID)",
            "PayloadUUID": profileUUID,
            "PayloadDisplayName": "Device Management",
            "PayloadDescription": "This profile will enroll your device for management.",
            "PayloadOrganization": "Your Organization",
            "PayloadContent": [mdmPayload]
        ]

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: profile,
                format: .xml,
                options: 0
            )
            return data
        } catch {
            print("Failed to build enrollment profile: \(error)")
            return nil
        }
    }
}
