import Foundation

/// Centralized app configuration
enum AppConfig {
    // MARK: - API Configuration

    /// Base URL for the API
    static var apiBaseURL: String {
        #if DEBUG
        // Use environment variable if set, otherwise default to production
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            return envURL
        }
        #endif
        return "https://focusphone-api.orangehill-4bbb582f.eastus.azurecontainerapps.io/api"
    }

    /// Request timeout in seconds (allows for Azure cold start)
    static let requestTimeout: TimeInterval = 30

    /// Resource timeout in seconds
    static let resourceTimeout: TimeInterval = 60

    // MARK: - Token Configuration

    /// How long before token expiry to trigger refresh (seconds)
    static let tokenRefreshBuffer: TimeInterval = 60

    /// Minimum time a token should be valid before allowing use
    static let tokenMinimumValidity: TimeInterval = 30

    // MARK: - Retry Configuration

    /// Maximum number of retry attempts for transient failures
    static let maxRetryAttempts = 3

    /// Base delay between retries (exponential backoff)
    static let retryBaseDelay: TimeInterval = 1.0

    // MARK: - UI Configuration

    /// How long to show loading states before considering them "stuck"
    static let loadingTimeout: TimeInterval = 45

    /// Device is considered online if checked in within this time (seconds)
    static let deviceOnlineThreshold: TimeInterval = 24 * 60 * 60

    // MARK: - Keychain Keys

    static let keychainTokenKey = "com.focusphone.parent.token"
    static let keychainProviderKey = "com.focusphone.parent.provider"

    // MARK: - App Info

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }
}
