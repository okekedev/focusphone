import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(String)
    case decodingFailed
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let message):
            return message
        case .decodingFailed:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized"
        }
    }
}

class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "http://localhost:8000/api"
    #else
    private let baseURL = "https://focusphone-api.orangehill-4bbb582f.eastus.azurecontainerapps.io/api"
    #endif

    private var token: String?
    private var provider: String = "apple"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func setToken(_ token: String) {
        self.token = token
    }

    func setProvider(_ provider: String) {
        self.provider = provider
    }

    func clearAuth() {
        self.token = nil
    }

    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(provider, forHTTPHeaderField: "X-Auth-Provider")
        }

        if let body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                throw APIError.requestFailed(detail)
            }
            throw APIError.requestFailed("Request failed with status \(httpResponse.statusCode)")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingFailed
        }
    }

    // MARK: - Auth

    func getMe() async throws -> User {
        let response: AuthResponse = try await request("/auth/me")
        return response.user
    }

    // MARK: - Devices

    func getDevices() async throws -> [Device] {
        try await request("/devices")
    }

    func getDevice(id: String) async throws -> Device {
        try await request("/devices/\(id)")
    }

    func deleteDevice(id: String) async throws {
        let _: [String: String] = try await request("/devices/\(id)", method: "DELETE")
    }

    func unenrollDevice(id: String) async throws {
        let _: [String: String] = try await request("/devices/\(id)/unenroll", method: "POST")
    }

    // MARK: - Profiles

    func getProfiles() async throws -> [Profile] {
        try await request("/profiles")
    }

    func assignProfile(profileId: String, deviceId: String) async throws {
        let body = try JSONEncoder().encode(["deviceId": deviceId])
        let _: [String: String] = try await request("/profiles/\(profileId)/assign", method: "POST", body: body)
    }

    // MARK: - Enrollment

    func createEnrollmentToken() async throws -> EnrollmentToken {
        try await request("/enrollment/token", method: "POST")
    }
}
