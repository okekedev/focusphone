import SwiftUI
import AuthenticationServices

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    private let keychain = KeychainHelper.shared

    init() {
        // Check for existing token on launch
        if let token = keychain.getToken() {
            APIClient.shared.setToken(token)
            if let provider = keychain.getProvider() {
                APIClient.shared.setProvider(provider)
            }
            Task {
                await checkAuthStatus()
            }
        }
    }

    func checkAuthStatus() async {
        isLoading = true
        do {
            currentUser = try await APIClient.shared.getMe()
            isAuthenticated = true
        } catch {
            // Token invalid or expired
            signOut()
        }
        isLoading = false
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
        keychain.saveToken(tokenString)
        keychain.saveProvider("apple")
        APIClient.shared.setToken(tokenString)
        APIClient.shared.setProvider("apple")

        do {
            currentUser = try await APIClient.shared.getMe()
            isAuthenticated = true
        } catch let apiError {
            error = apiError.localizedDescription
            keychain.deleteToken()
        }

        isLoading = false
    }

    func signOut() {
        keychain.deleteToken()
        keychain.deleteProvider()
        APIClient.shared.clearAuth()
        isAuthenticated = false
        currentUser = nil
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()

    private let tokenKey = "com.focusphone.parent.token"
    private let providerKey = "com.focusphone.parent.provider"

    func saveToken(_ token: String) {
        save(key: tokenKey, data: token.data(using: .utf8)!)
    }

    func getToken() -> String? {
        guard let data = load(key: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        delete(key: tokenKey)
    }

    func saveProvider(_ provider: String) {
        save(key: providerKey, data: provider.data(using: .utf8)!)
    }

    func getProvider() -> String? {
        guard let data = load(key: providerKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteProvider() {
        delete(key: providerKey)
    }

    private func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
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
