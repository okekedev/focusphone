import Foundation

// MARK: - API Client
// Handles communication between apps and MDM backend

class APIClient: ObservableObject {
    static let shared = APIClient()

    @Published var isAuthenticated = false
    @Published var currentUser: APIUser?

    private var baseURL: URL
    private var authToken: String?

    init(baseURL: URL = URL(string: "https://your-mdm-server.com/api")!) {
        self.baseURL = baseURL
        loadStoredToken()
    }

    // MARK: - Configuration

    func configure(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws -> APIUser {
        let endpoint = baseURL.appendingPathComponent("auth/login")
        let body = ["email": email, "password": password]

        let response: AuthResponse = try await post(endpoint, body: body)

        await MainActor.run {
            self.authToken = response.token
            self.currentUser = response.user
            self.isAuthenticated = true
        }

        storeToken(response.token)
        return response.user
    }

    func logout() {
        authToken = nil
        currentUser = nil
        isAuthenticated = false
        clearStoredToken()
    }

    func register(email: String, password: String, name: String) async throws -> APIUser {
        let endpoint = baseURL.appendingPathComponent("auth/register")
        let body = ["email": email, "password": password, "name": name]

        let response: AuthResponse = try await post(endpoint, body: body)

        await MainActor.run {
            self.authToken = response.token
            self.currentUser = response.user
            self.isAuthenticated = true
        }

        storeToken(response.token)
        return response.user
    }

    // MARK: - Devices

    func getDevices() async throws -> [APIDevice] {
        let endpoint = baseURL.appendingPathComponent("devices")
        return try await get(endpoint)
    }

    func getDevice(id: String) async throws -> APIDevice {
        let endpoint = baseURL.appendingPathComponent("devices/\(id)")
        return try await get(endpoint)
    }

    func enrollDevice(token: String) async throws -> EnrollmentResponse {
        let endpoint = baseURL.appendingPathComponent("devices/enroll")
        let body = ["token": token]
        return try await post(endpoint, body: body)
    }

    func unenrollDevice(id: String) async throws {
        let endpoint = baseURL.appendingPathComponent("devices/\(id)/unenroll")
        let _: EmptyResponse = try await post(endpoint, body: EmptyRequest())
    }

    // MARK: - Profiles

    func getProfiles() async throws -> [APIProfile] {
        let endpoint = baseURL.appendingPathComponent("profiles")
        return try await get(endpoint)
    }

    func createProfile(_ profile: CreateProfileRequest) async throws -> APIProfile {
        let endpoint = baseURL.appendingPathComponent("profiles")
        return try await post(endpoint, body: profile)
    }

    func assignProfile(profileId: String, deviceId: String) async throws {
        let endpoint = baseURL.appendingPathComponent("profiles/\(profileId)/assign")
        let body = ["deviceId": deviceId]
        let _: EmptyResponse = try await post(endpoint, body: body)
    }

    // MARK: - Enrollment Tokens

    func createEnrollmentToken() async throws -> APIEnrollmentToken {
        let endpoint = baseURL.appendingPathComponent("enrollment/token")
        return try await post(endpoint, body: EmptyRequest())
    }

    func getEnrollmentURL(token: String) -> URL {
        baseURL.appendingPathComponent("enroll/\(token)")
    }

    // MARK: - Users (Admin)

    func getUsers() async throws -> [APIUser] {
        let endpoint = baseURL.appendingPathComponent("users")
        return try await get(endpoint)
    }

    func inviteUser(email: String) async throws {
        let endpoint = baseURL.appendingPathComponent("users/invite")
        let body = ["email": email]
        let _: EmptyResponse = try await post(endpoint, body: body)
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }

    // MARK: - Token Storage

    private func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "mdm_auth_token")
    }

    private func loadStoredToken() {
        authToken = UserDefaults.standard.string(forKey: "mdm_auth_token")
        isAuthenticated = authToken != nil
    }

    private func clearStoredToken() {
        UserDefaults.standard.removeObject(forKey: "mdm_auth_token")
    }
}

// MARK: - API Types

struct APIUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let createdAt: Date?
}

struct APIDevice: Codable, Identifiable {
    let id: String
    let udid: String
    let name: String
    let model: String
    let osVersion: String
    let status: String
    let profileId: String?
    let lastCheckin: Date?
}

struct APIProfile: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let allowPhone: Bool
    let allowMessages: Bool
    let allowCamera: Bool
    let allowPhotos: Bool
    let deviceCount: Int
}

struct APIEnrollmentToken: Codable {
    let token: String
    let expiresAt: Date
    let enrollmentURL: String
}

struct AuthResponse: Codable {
    let token: String
    let user: APIUser
}

struct EnrollmentResponse: Codable {
    let success: Bool
    let deviceId: String?
    let message: String
}

struct CreateProfileRequest: Codable {
    let name: String
    let description: String
    let allowPhone: Bool
    let allowMessages: Bool
    let allowCamera: Bool
    let allowPhotos: Bool
}

struct EmptyResponse: Codable {}
struct EmptyRequest: Codable {}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Please log in again"
        case .forbidden:
            return "You don't have permission"
        case .notFound:
            return "Not found"
        case .serverError:
            return "Server error. Please try again."
        case .unknown(let code):
            return "Error: \(code)"
        }
    }
}
