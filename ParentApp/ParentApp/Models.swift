import Foundation

struct Device: Codable, Identifiable {
    let id: String
    let udid: String
    let name: String
    let model: String
    let osVersion: String
    let serialNumber: String?
    let status: String
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
}

struct Profile: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let allowPhone: Bool
    let allowMessages: Bool
    let allowContacts: Bool
    let allowCamera: Bool
    let allowPhotos: Bool
    let deviceCount: Int
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let provider: String?
    let phoneVerified: Bool?
    let createdAt: Date?
}

struct EnrollmentToken: Codable {
    let token: String
    let expiresAt: Date
    let enrollmentURL: String
    let qrCodeURL: String
}

struct AuthResponse: Codable {
    let user: User
}
