import Foundation

// MARK: - Enums

enum DeviceStatus: String, Codable, Sendable {
    case pending
    case enrolled
    case managed
    case unenrolling
    case removed
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = DeviceStatus(rawValue: rawValue) ?? .unknown
    }
}

enum UserRole: String, Codable, Sendable {
    case admin
    case user
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = UserRole(rawValue: rawValue) ?? .unknown
    }
}

enum AuthProvider: String, Codable, Sendable {
    case apple
    case google
    case microsoft
    case dev
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AuthProvider(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - Models

struct Device: Codable, Identifiable, Sendable {
    let id: String
    let udid: String
    let name: String
    let model: String
    let osVersion: String
    let serialNumber: String?
    let status: DeviceStatus
    let profileId: String?
    let lastCheckin: Date?
    let batteryLevel: Double?
    let latitude: Double?
    let longitude: Double?
    let locationUpdatedAt: Date?
    let ownerId: String?

    var isOnline: Bool {
        guard let lastCheckin else { return false }
        return Date().timeIntervalSince(lastCheckin) < 24 * 60 * 60
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var statusDisplayName: String {
        switch status {
        case .pending: return "Pending"
        case .enrolled: return "Enrolled"
        case .managed: return "Managed"
        case .unenrolling: return "Unenrolling"
        case .removed: return "Removed"
        case .unknown: return "Unknown"
        }
    }
}

struct Profile: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let description: String
    let allowPhone: Bool
    let allowMessages: Bool
    let allowContacts: Bool
    let allowCamera: Bool
    let allowPhotos: Bool
    let deviceCount: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }
}

struct User: Codable, Identifiable, Sendable {
    let id: String
    let email: String
    let name: String
    let role: UserRole
    let provider: AuthProvider?
    let phoneVerified: Bool?
    let createdAt: Date?

    // Coding keys to handle string values from API
    enum CodingKeys: String, CodingKey {
        case id, email, name, role, provider, phoneVerified, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(UserRole.self, forKey: .role)
        provider = try container.decodeIfPresent(AuthProvider.self, forKey: .provider)
        phoneVerified = try container.decodeIfPresent(Bool.self, forKey: .phoneVerified)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(id: String, email: String, name: String, role: UserRole, provider: AuthProvider?, phoneVerified: Bool?, createdAt: Date?) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.provider = provider
        self.phoneVerified = phoneVerified
        self.createdAt = createdAt
    }
}

struct EnrollmentToken: Codable, Sendable {
    let token: String
    let expiresAt: Date
    let enrollmentURL: String
    let qrCodeURL: String
    let profileId: String?

    var isValid: Bool {
        expiresAt > Date()
    }

    var isExpiringSoon: Bool {
        expiresAt.timeIntervalSinceNow < 120 // Less than 2 minutes
    }
}

struct AuthResponse: Codable, Sendable {
    let user: User
}
