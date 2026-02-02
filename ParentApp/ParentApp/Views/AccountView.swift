import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FPSpacing.lg) {
                        // Profile header
                        profileHeader

                        // Account info
                        accountInfoSection

                        // App info
                        appInfoSection

                        // Sign out
                        signOutSection
                    }
                    .padding(FPSpacing.md)
                }
            }
            .navigationTitle("Account")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        FPCard(padding: FPSpacing.lg) {
            VStack(spacing: FPSpacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(FPColors.primaryGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: FPColors.primary.opacity(0.3), radius: 12, y: 6)

                    Text(initials)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(spacing: FPSpacing.xs) {
                    Text(authManager.currentUser?.name ?? "Parent")
                        .font(FPTypography.title2)
                        .foregroundColor(FPColors.textPrimary)

                    if let email = authManager.currentUser?.email {
                        Text(email)
                            .font(FPTypography.subheadline)
                            .foregroundColor(FPColors.textSecondary)
                    }
                }

                // Provider badge
                HStack(spacing: FPSpacing.xs) {
                    Image(systemName: providerIcon)
                        .font(.system(size: 12))
                    Text("Signed in with \(providerName)")
                        .font(FPTypography.caption)
                }
                .foregroundColor(FPColors.textTertiary)
                .padding(.horizontal, FPSpacing.md)
                .padding(.vertical, FPSpacing.xs)
                .background(
                    Capsule()
                        .fill(FPColors.surfaceSecondary)
                )
            }
        }
    }

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        FPCard {
            VStack(alignment: .leading, spacing: FPSpacing.sm) {
                Text("Account")
                    .font(FPTypography.caption)
                    .foregroundColor(FPColors.textTertiary)
                    .textCase(.uppercase)
                    .padding(.bottom, FPSpacing.xs)

                if let email = authManager.currentUser?.email {
                    AccountRow(icon: "envelope.fill", title: "Email", value: email)
                }

                Divider()

                if let createdAt = authManager.currentUser?.createdAt {
                    AccountRow(
                        icon: "calendar",
                        title: "Member since",
                        value: createdAt.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        FPCard {
            VStack(alignment: .leading, spacing: FPSpacing.sm) {
                Text("App")
                    .font(FPTypography.caption)
                    .foregroundColor(FPColors.textTertiary)
                    .textCase(.uppercase)
                    .padding(.bottom, FPSpacing.xs)

                AccountRow(icon: "info.circle", title: "Version", value: AppConfig.fullVersion)

                Divider()

                AccountRow(icon: platformIcon, title: "Platform", value: platformName)

                Divider()

                // Support link
                Button {
                    // Open support
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(FPColors.primary)
                            .frame(width: 24)

                        Text("Help & Support")
                            .font(FPTypography.body)
                            .foregroundColor(FPColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(FPColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Button {
            authManager.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(FPTypography.headline)
            .foregroundColor(FPColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FPSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.error.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var initials: String {
        let name = authManager.currentUser?.name ?? "P"
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var providerIcon: String {
        switch authManager.currentUser?.provider {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .microsoft: return "window.horizontal.closed"
        case .dev: return "hammer.fill"
        default: return "person.circle"
        }
    }

    private var providerName: String {
        switch authManager.currentUser?.provider {
        case .apple: return "Apple"
        case .google: return "Google"
        case .microsoft: return "Microsoft"
        case .dev: return "Dev Mode"
        default: return "Unknown"
        }
    }

    private var platformIcon: String {
        #if os(iOS)
        return "iphone"
        #elseif os(macOS)
        return "desktopcomputer"
        #else
        return "questionmark"
        #endif
    }

    private var platformName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(FPColors.primary)
                .frame(width: 24)

            Text(title)
                .font(FPTypography.body)
                .foregroundColor(FPColors.textSecondary)

            Spacer()

            Text(value)
                .font(FPTypography.body)
                .foregroundColor(FPColors.textPrimary)
                .lineLimit(1)
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthManager())
}
