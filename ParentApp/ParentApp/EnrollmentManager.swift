import SwiftUI
import os.log

@MainActor
class EnrollmentManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var tokens: [String: EnrollmentToken] = [:]
    @Published var failedTokens: Set<String> = []
    @Published var isLoadingProfiles = false
    @Published var isGenerating = false
    @Published var error: String?

    private var refreshTasks: [String: Task<Void, Never>] = [:]
    private var loadTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.focusphone.parent", category: "EnrollmentManager")

    init() {
        loadTask = Task { [weak self] in
            await self?.loadProfilesAndGenerateTokens()
        }
    }

    /// Call this method to clean up tasks before the manager is deallocated
    func cleanup() {
        loadTask?.cancel()
        loadTask = nil
        for task in refreshTasks.values {
            task.cancel()
        }
        refreshTasks.removeAll()
    }

    // MARK: - Public API

    /// Get a valid token for a profile, or nil if not available
    func token(for profileId: String) -> EnrollmentToken? {
        guard let token = tokens[profileId],
              token.isValid else {
            return nil
        }
        return token
    }

    /// Check if a profile has a valid token ready
    func isTokenReady(for profileId: String) -> Bool {
        token(for: profileId) != nil
    }

    /// Check if a profile's token is expiring soon
    func isTokenExpiringSoon(for profileId: String) -> Bool {
        guard let token = tokens[profileId] else { return false }
        return token.isExpiringSoon
    }

    /// Check if token generation failed for a profile
    func hasTokenFailed(for profileId: String) -> Bool {
        failedTokens.contains(profileId)
    }

    /// Check if a specific profile is currently generating a token
    func isGeneratingToken(for profileId: String) -> Bool {
        isGenerating && !isTokenReady(for: profileId) && !hasTokenFailed(for: profileId)
    }

    /// Retry loading everything
    func reload() async {
        // Cancel existing operations
        loadTask?.cancel()
        refreshTasks.values.forEach { $0.cancel() }
        refreshTasks.removeAll()

        // Clear error states
        error = nil
        failedTokens.removeAll()

        await loadProfilesAndGenerateTokens()
    }

    /// Regenerate token for a specific profile
    func regenerateToken(for profileId: String) async {
        // Cancel existing refresh for this profile
        refreshTasks[profileId]?.cancel()
        refreshTasks.removeValue(forKey: profileId)

        // Remove from failed set if present
        failedTokens.remove(profileId)

        await generateToken(for: profileId)
    }

    /// Regenerate all tokens
    func regenerateAllTokens() async {
        refreshTasks.values.forEach { $0.cancel() }
        refreshTasks.removeAll()
        tokens.removeAll()
        failedTokens.removeAll()
        await generateTokensForAllProfiles()
    }

    // MARK: - Loading

    private func loadProfilesAndGenerateTokens() async {
        isLoadingProfiles = true
        defer { isLoadingProfiles = false }

        do {
            profiles = try await APIClient.shared.getProfiles()
            logger.info("Loaded \(self.profiles.count) profiles")
        } catch {
            logger.error("Failed to load profiles: \(error.localizedDescription)")
            self.error = error.localizedDescription
            return
        }

        await generateTokensForAllProfiles()
    }

    private func generateTokensForAllProfiles() async {
        guard !profiles.isEmpty else {
            logger.debug("No profiles to generate tokens for")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        logger.info("Generating tokens for \(self.profiles.count) profiles")

        // Collect results from parallel token generation
        let results = await withTaskGroup(of: (String, Result<EnrollmentToken, Error>).self) { group -> [(String, Result<EnrollmentToken, Error>)] in
            for profile in profiles {
                group.addTask { [profileId = profile.id] in
                    do {
                        let token = try await APIClient.shared.createEnrollmentToken(profileId: profileId)
                        return (profileId, .success(token))
                    } catch {
                        return (profileId, .failure(error))
                    }
                }
            }

            var collected: [(String, Result<EnrollmentToken, Error>)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        // Process results on MainActor
        var successCount = 0
        var failureCount = 0

        for (profileId, result) in results {
            switch result {
            case .success(let token):
                tokens[profileId] = token
                failedTokens.remove(profileId)
                scheduleRefresh(for: profileId)
                successCount += 1

            case .failure(let error):
                logger.warning("Failed to create token for profile \(profileId): \(error.localizedDescription)")
                failedTokens.insert(profileId)
                failureCount += 1
            }
        }

        logger.info("Token generation complete: \(successCount) succeeded, \(failureCount) failed")
    }

    private func generateToken(for profileId: String) async {
        do {
            let token = try await APIClient.shared.createEnrollmentToken(profileId: profileId)
            tokens[profileId] = token
            failedTokens.remove(profileId)
            scheduleRefresh(for: profileId)
            logger.debug("Regenerated token for profile \(profileId)")
        } catch {
            logger.warning("Failed to generate token for profile \(profileId): \(error.localizedDescription)")
            failedTokens.insert(profileId)
        }
    }

    // MARK: - Token Refresh Scheduling

    private func scheduleRefresh(for profileId: String) {
        // Cancel any existing refresh task for this profile
        if let existingTask = refreshTasks[profileId] {
            existingTask.cancel()
            refreshTasks.removeValue(forKey: profileId)
        }

        guard let token = tokens[profileId] else { return }

        // Calculate when to refresh (before expiry)
        let refreshTime = token.expiresAt.addingTimeInterval(-AppConfig.tokenRefreshBuffer)
        let delay = refreshTime.timeIntervalSinceNow

        if delay <= 0 {
            // Token already expired or about to expire, regenerate immediately
            logger.debug("Token for profile \(profileId) expired, regenerating now")
            let task = Task { [weak self] in
                guard !Task.isCancelled else { return }
                await self?.generateToken(for: profileId)
            }
            // Don't store this task since it's immediate
            refreshTasks[profileId] = task
            return
        }

        logger.debug("Scheduling token refresh for profile \(profileId) in \(Int(delay))s")

        // Schedule refresh
        refreshTasks[profileId] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.generateToken(for: profileId)
                // Clean up task reference after completion
                self?.refreshTasks.removeValue(forKey: profileId)
            } catch {
                // Task was cancelled, that's fine
            }
        }
    }
}
