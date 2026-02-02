import Foundation
import os.log

// MARK: - API Error Types

enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case requestFailed(String, statusCode: Int?)
    case decodingFailed(String)
    case unauthorized
    case networkError(String)
    case timeout
    case serverError(Int)
    case rateLimited
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let message, _):
            return message
        case .decodingFailed(let details):
            return "Failed to decode response: \(details)"
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .noData:
            return "No data received from server"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .serverError, .networkError, .rateLimited:
            return true
        case .invalidURL, .requestFailed, .decodingFailed, .unauthorized, .noData:
            return false
        }
    }
}

// MARK: - API Client

final class APIClient: Sendable {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.focusphone.parent", category: "APIClient")

    // Thread-safe token storage using actor
    private let tokenStore = TokenStore()

    init() {
        self.baseURL = AppConfig.apiBaseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        config.timeoutIntervalForResource = AppConfig.resourceTimeout
        self.session = URLSession(configuration: config)

        self.decoder = Self.makeDecoder()
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601DateFormatter first (handles most standard cases including timezone)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Fallback without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Manual formats for edge cases
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",      // Microseconds with Z
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZ",   // Microseconds with +00:00
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // Microseconds no TZ
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ",      // Milliseconds with +00:00
                "yyyy-MM-dd'T'HH:mm:ss.SSS",          // Milliseconds no TZ
                "yyyy-MM-dd'T'HH:mm:ssZZZZ",          // No fraction with +00:00
                "yyyy-MM-dd'T'HH:mm:ss"               // No fraction no TZ
            ]

            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }

    // MARK: - Token Management

    func setToken(_ token: String) async {
        await tokenStore.setToken(token)
    }

    func setProvider(_ provider: AuthProvider) async {
        await tokenStore.setProvider(provider)
    }

    func setProvider(_ provider: String) async {
        let authProvider = AuthProvider(rawValue: provider) ?? .unknown
        await tokenStore.setProvider(authProvider)
    }

    func clearAuth() async {
        await tokenStore.clear()
    }

    // MARK: - Request Execution

    private func request<T: Decodable & Sendable>(
        _ endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        retryCount: Int = 0
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            logger.error("Invalid URL: \(self.baseURL + endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get auth headers
        let (token, provider) = await tokenStore.getCredentials()
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let provider = provider {
                request.setValue(provider.rawValue, forHTTPHeaderField: "X-Auth-Provider")
            }
        }

        if let body = body {
            request.httpBody = body
        }

        logger.debug("[\(method)] \(endpoint)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type for \(endpoint)")
                throw APIError.requestFailed("Invalid response", statusCode: nil)
            }

            let statusCode = httpResponse.statusCode
            logger.debug("[\(method)] \(endpoint) -> \(statusCode)")

            // Handle specific status codes
            switch statusCode {
            case 200...299:
                break // Success, continue to decode

            case 401:
                logger.warning("Unauthorized request to \(endpoint)")
                throw APIError.unauthorized

            case 429:
                logger.warning("Rate limited on \(endpoint)")
                if retryCount < AppConfig.maxRetryAttempts {
                    let delay = AppConfig.retryBaseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await self.request(endpoint, method: method, body: body, retryCount: retryCount + 1)
                }
                throw APIError.rateLimited

            case 500...599:
                logger.error("Server error \(statusCode) on \(endpoint)")
                if retryCount < AppConfig.maxRetryAttempts {
                    let delay = AppConfig.retryBaseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await self.request(endpoint, method: method, body: body, retryCount: retryCount + 1)
                }
                throw APIError.serverError(statusCode)

            default:
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorJson["detail"] as? String {
                    logger.error("Request failed: \(detail)")
                    throw APIError.requestFailed(detail, statusCode: statusCode)
                }
                throw APIError.requestFailed("Request failed with status \(statusCode)", statusCode: statusCode)
            }

            // Decode response
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError {
                logger.error("Decoding error for \(endpoint): \(decodingError)")
                throw APIError.decodingFailed(String(describing: decodingError))
            }

        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            logger.error("URL error for \(endpoint): \(urlError.localizedDescription)")

            switch urlError.code {
            case .timedOut:
                if retryCount < AppConfig.maxRetryAttempts {
                    let delay = AppConfig.retryBaseDelay * pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await self.request(endpoint, method: method, body: body, retryCount: retryCount + 1)
                }
                throw APIError.timeout

            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkError("No internet connection")

            default:
                throw APIError.networkError(urlError.localizedDescription)
            }
        } catch {
            logger.error("Unexpected error for \(endpoint): \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
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
        guard !id.isEmpty else {
            throw APIError.invalidURL
        }
        return try await request("/devices/\(id)")
    }

    func deleteDevice(id: String) async throws {
        guard !id.isEmpty else {
            throw APIError.invalidURL
        }
        let _: EmptyResponse = try await request("/devices/\(id)", method: "DELETE")
    }

    func unenrollDevice(id: String) async throws {
        guard !id.isEmpty else {
            throw APIError.invalidURL
        }
        let _: EmptyResponse = try await request("/devices/\(id)/unenroll", method: "POST")
    }

    // MARK: - Profiles

    func getProfiles() async throws -> [Profile] {
        try await request("/profiles")
    }

    func assignProfile(profileId: String, deviceId: String) async throws {
        guard !profileId.isEmpty, !deviceId.isEmpty else {
            throw APIError.invalidURL
        }
        let body = try JSONEncoder().encode(["deviceId": deviceId])
        let _: EmptyResponse = try await request("/profiles/\(profileId)/assign", method: "POST", body: body)
    }

    // MARK: - Enrollment

    func createEnrollmentToken(profileId: String) async throws -> EnrollmentToken {
        guard !profileId.isEmpty else {
            throw APIError.invalidURL
        }
        let body = try JSONEncoder().encode(["profileId": profileId])
        return try await request("/enrollment/token", method: "POST", body: body)
    }
}

// MARK: - Token Store Actor

private actor TokenStore {
    private var token: String?
    private var provider: AuthProvider?

    func setToken(_ token: String) {
        self.token = token
    }

    func setProvider(_ provider: AuthProvider) {
        self.provider = provider
    }

    func getCredentials() -> (String?, AuthProvider?) {
        return (token, provider)
    }

    func clear() {
        token = nil
        provider = nil
    }
}

// MARK: - Empty Response

private struct EmptyResponse: Decodable, Sendable {
    // Handles responses like {"message": "..."} or empty responses
    init(from decoder: Decoder) throws {
        // Accept any valid JSON
        _ = try? decoder.singleValueContainer()
    }
}
