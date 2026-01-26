import Foundation
import SwiftData

// MARK: - User
// Account that owns devices and manages restrictions

@Model
final class User {
    var id: UUID = UUID()
    var email: String = ""
    var name: String = ""
    var role: String = UserRole.user.rawValue
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Device.owner)
    var devices: [Device]?

    @Transient var userRole: UserRole {
        get { UserRole(rawValue: role) ?? .user }
        set { role = newValue.rawValue }
    }

    init(email: String, name: String, role: UserRole = .user) {
        self.id = UUID()
        self.email = email
        self.name = name
        self.role = role.rawValue
        self.createdAt = Date()
    }
}

enum UserRole: String, Codable, CaseIterable {
    case admin = "admin"
    case user = "user"
}

// MARK: - Device
// An enrolled iOS device

@Model
final class Device {
    var id: UUID = UUID()
    var udid: String = ""
    var name: String = ""
    var model: String = ""
    var osVersion: String = ""
    var serialNumber: String = ""
    var pushToken: String = ""  // APNs token for MDM push
    var enrolledAt: Date = Date()
    var lastCheckin: Date = Date()
    var statusRaw: String = DeviceStatus.pending.rawValue

    var owner: User?

    @Relationship(deleteRule: .nullify, inverse: \RestrictionProfile.devices)
    var profile: RestrictionProfile?

    @Transient var status: DeviceStatus {
        get { DeviceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(udid: String, name: String, model: String = "", osVersion: String = "") {
        self.id = UUID()
        self.udid = udid
        self.name = name
        self.model = model
        self.osVersion = osVersion
        self.enrolledAt = Date()
        self.lastCheckin = Date()
    }
}

enum DeviceStatus: String, Codable {
    case pending = "pending"           // Enrollment started
    case enrolled = "enrolled"         // Successfully enrolled
    case managed = "managed"           // Profile installed
    case unenrolling = "unenrolling"   // User requested removal
    case removed = "removed"           // MDM removed
}

// MARK: - Restriction Profile
// Defines what apps are allowed on the device

@Model
final class RestrictionProfile {
    var id: UUID = UUID()
    var name: String = ""
    var descriptionText: String = ""
    var allowPhone: Bool = true
    var allowMessages: Bool = true
    var allowCamera: Bool = true
    var allowPhotos: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var devices: [Device]?

    init(name: String, description: String = "") {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Bundle IDs for allowlisted apps
    var allowedBundleIDs: [String] {
        var bundles: [String] = []
        if allowPhone { bundles.append("com.apple.mobilephone") }
        if allowMessages { bundles.append("com.apple.MobileSMS") }
        if allowCamera { bundles.append("com.apple.camera") }
        if allowPhotos { bundles.append("com.apple.mobileslideshow") }
        return bundles
    }
}

// MARK: - MDM Command
// Commands queued for devices

@Model
final class MDMCommand {
    var id: UUID = UUID()
    var commandType: String = ""
    var payload: Data?
    var statusRaw: String = CommandStatus.pending.rawValue
    var createdAt: Date = Date()
    var sentAt: Date?
    var acknowledgedAt: Date?
    var errorMessage: String?

    var deviceUDID: String = ""

    @Transient var status: CommandStatus {
        get { CommandStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(type: String, deviceUDID: String, payload: Data? = nil) {
        self.id = UUID()
        self.commandType = type
        self.deviceUDID = deviceUDID
        self.payload = payload
        self.createdAt = Date()
    }
}

enum CommandStatus: String, Codable {
    case pending = "pending"
    case sent = "sent"
    case acknowledged = "acknowledged"
    case failed = "failed"
}

// MARK: - Enrollment Token
// One-time tokens for device enrollment

@Model
final class EnrollmentToken {
    var id: UUID = UUID()
    var token: String = ""
    var createdAt: Date = Date()
    var expiresAt: Date = Date()
    var usedAt: Date?
    var isUsed: Bool = false

    var ownerEmail: String = ""

    init(ownerEmail: String, validFor: TimeInterval = 3600) {
        self.id = UUID()
        self.token = UUID().uuidString
        self.ownerEmail = ownerEmail
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(validFor)
    }

    var isValid: Bool {
        !isUsed && Date() < expiresAt
    }
}
