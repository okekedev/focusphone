import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.linearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.name ?? "Parent")
                                .font(.title2)
                                .fontWeight(.semibold)

                            if let email = authManager.currentUser?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Account Info Section
                Section("Account Info") {
                    if let email = authManager.currentUser?.email {
                        InfoRow(icon: "envelope.fill", title: "Email", value: email)
                    }

                    InfoRow(
                        icon: providerIcon,
                        title: "Signed in with",
                        value: providerName
                    )

                    if let createdAt = authManager.currentUser?.createdAt {
                        InfoRow(
                            icon: "calendar",
                            title: "Member since",
                            value: createdAt.formatted(date: .long, time: .omitted)
                        )
                    }
                }

                // App Info Section
                Section("App Info") {
                    InfoRow(icon: "info.circle", title: "Version", value: "1.0.0")
                    InfoRow(icon: "iphone", title: "Platform", value: platformName)
                }

                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Account")
        }
    }

    private var providerIcon: String {
        switch authManager.currentUser?.provider {
        case "apple": return "apple.logo"
        case "google": return "g.circle.fill"
        case "microsoft": return "window.horizontal.closed"
        default: return "person.circle"
        }
    }

    private var providerName: String {
        switch authManager.currentUser?.provider {
        case "apple": return "Apple"
        case "google": return "Google"
        case "microsoft": return "Microsoft"
        default: return "Unknown"
        }
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

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthManager())
}
