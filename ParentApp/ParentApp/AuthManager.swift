import SwiftUI
import AuthenticationServices
import os.log

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true  // Start as true to prevent flash
    @Published var error: String?

    private let keychain = KeychainHelper.shared
    private let logger = Logger(subsystem: "com.focusphone.parent", category: "AuthManager")

    init() {
        // Check for existing token on launch
        if let token = keychain.getToken() {
            // Validate the token asynchronously
            Task {
                await APIClient.shared.setToken(token)
                if let provider = keychain.getProvider() {
                    await APIClient.shared.setProvider(provider)
                }
                await checkAuthStatus()
            }
        } else {
            // No token, not loading
            isLoading = false
        }
    }

    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await APIClient.shared.getMe()
            isAuthenticated = true
            logger.info("Auth validated for user: \(self.currentUser?.email ?? "unknown")")
        } catch let error as APIError {
            logger.warning("Auth check failed: \(error.localizedDescription)")
            if case .unauthorized = error {
                // Token invalid or expired - clear and require re-auth
                signOut()
            } else {
                // Network error - keep token but show error
                self.error = error.localizedDescription
            }
        } catch {
            logger.error("Unexpected auth error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to get Apple ID token"
            return
        }

        isLoading = true
        error = nil

        // Store the token and set provider
        do {
            try keychain.saveToken(tokenString)
            try keychain.saveProvider(AuthProvider.apple.rawValue)
        } catch {
            logger.error("Failed to save credentials to keychain: \(error.localizedDescription)")
            self.error = "Failed to save credentials securely"
            isLoading = false
            return
        }

        await APIClient.shared.setToken(tokenString)
        await APIClient.shared.setProvider(AuthProvider.apple)

        do {
            currentUser = try await APIClient.shared.getMe()
            isAuthenticated = true
            logger.info("Signed in with Apple: \(self.currentUser?.email ?? "unknown")")
        } catch let apiError {
            logger.error("Sign in failed: \(apiError.localizedDescription)")
            error = apiError.localizedDescription
            keychain.deleteToken()
            keychain.deleteProvider()
        }

        isLoading = false
    }

    func signOut() {
        logger.info("Signing out user: \(self.currentUser?.email ?? "unknown")")
        keychain.deleteToken()
        keychain.deleteProvider()
        Task { await APIClient.shared.clearAuth() }
        isAuthenticated = false
        currentUser = nil
        error = nil
    }

    func clearError() {
        error = nil
    }

    #if DEBUG
    func signInWithDevMode() async {
        // Only allow dev mode in simulator or with explicit flag
        #if targetEnvironment(simulator)
        isLoading = true
        error = nil

        let devToken = "dev-token-\(UUID().uuidString)"
        do {
            try keychain.saveToken(devToken)
            try keychain.saveProvider(AuthProvider.dev.rawValue)
        } catch {
            logger.error("Failed to save dev credentials: \(error.localizedDescription)")
        }

        await APIClient.shared.setToken(devToken)
        await APIClient.shared.setProvider(AuthProvider.dev)

        // Create mock user immediately
        currentUser = User(
            id: "dev-user-id",
            email: "dev@test.local",
            name: "Dev User",
            role: .admin,
            provider: .dev,
            phoneVerified: true,
            createdAt: nil
        )
        isAuthenticated = true
        isLoading = false

        logger.warning("Signed in with DEV MODE - simulator only")
        #else
        logger.error("Dev mode attempted on physical device - blocked")
        error = "Dev mode is only available in the simulator"
        #endif
    }
    #endif
}

// MARK: - Keychain Helper

final class KeychainHelper: Sendable {
    static let shared = KeychainHelper()

    private let tokenKey = AppConfig.keychainTokenKey
    private let providerKey = AppConfig.keychainProviderKey

    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case encodingFailed
    }

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(key: tokenKey, data: data)
    }

    func getToken() -> String? {
        guard let data = load(key: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        delete(key: tokenKey)
    }

    func saveProvider(_ provider: String) throws {
        guard let data = provider.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(key: providerKey, data: data)
    }

    func getProvider() -> String? {
        guard let data = load(key: providerKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteProvider() {
        delete(key: providerKey)
    }

    private func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
