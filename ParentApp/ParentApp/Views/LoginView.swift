import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showError = false
    @State private var animateGradient = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                backgroundGradient

                VStack(spacing: 0) {
                    Spacer()

                    // Logo and branding
                    brandingSection
                        .padding(.bottom, geometry.size.height * 0.08)

                    // Features
                    featuresSection
                        .padding(.bottom, FPSpacing.xxl)

                    Spacer()

                    // Sign in section
                    signInSection
                        .padding(.bottom, FPSpacing.xl)

                    // Footer
                    footerSection
                        .padding(.bottom, FPSpacing.lg)
                }
                .padding(.horizontal, FPSpacing.lg)
            }
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {
                authManager.clearError()
            }
        } message: {
            Text(authManager.error ?? "Unknown error occurred")
        }
        .onChange(of: authManager.error) { _, newValue in
            showError = newValue != nil
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            FPColors.background

            // Decorative circles
            Circle()
                .fill(FPColors.primary.opacity(0.08))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(FPColors.secondary.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 150, y: 100)

            Circle()
                .fill(FPColors.accent.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: -80, y: 300)
        }
        .ignoresSafeArea()
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: FPSpacing.md) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(FPColors.primaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: FPColors.primary.opacity(0.3), radius: 20, y: 10)

                Image(systemName: "iphone")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: FPSpacing.xs) {
                Text("FocusPhone")
                    .font(FPTypography.largeTitle)
                    .foregroundColor(FPColors.textPrimary)

                Text("Grounded in the essentials")
                    .font(FPTypography.subheadline)
                    .foregroundColor(FPColors.textSecondary)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: FPSpacing.md) {
            FeatureRow(
                icon: "shield.checkered",
                title: "Digital Wellness",
                subtitle: "Create healthy phone habits"
            )

            FeatureRow(
                icon: "heart.fill",
                title: "Family Focused",
                subtitle: "Perfect for kids, teens & anyone seeking simplicity"
            )

            FeatureRow(
                icon: "location.fill",
                title: "Peace of Mind",
                subtitle: "Know your loved ones are safe"
            )
        }
        .padding(.horizontal, FPSpacing.sm)
    }

    // MARK: - Sign In

    private var signInSection: some View {
        VStack(spacing: FPSpacing.md) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .cornerRadius(FPRadius.md)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)

            #if DEBUG
            Button {
                Task {
                    await authManager.signInWithDevMode()
                }
            } label: {
                HStack(spacing: FPSpacing.xs) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 12))
                    Text("Dev Mode")
                        .font(FPTypography.caption)
                }
                .foregroundColor(FPColors.textTertiary)
                .padding(.horizontal, FPSpacing.md)
                .padding(.vertical, FPSpacing.sm)
                .background(
                    Capsule()
                        .fill(FPColors.surfaceSecondary)
                )
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: FPSpacing.sm) {
            Text("By continuing, you agree to our")
                .font(FPTypography.footnote)
                .foregroundColor(FPColors.textTertiary)

            HStack(spacing: FPSpacing.xs) {
                Button("Terms of Service") {}
                    .font(FPTypography.footnote.weight(.medium))
                    .foregroundColor(FPColors.primary)

                Text("and")
                    .font(FPTypography.footnote)
                    .foregroundColor(FPColors.textTertiary)

                Button("Privacy Policy") {}
                    .font(FPTypography.footnote.weight(.medium))
                    .foregroundColor(FPColors.primary)
            }
        }
    }

    // MARK: - Actions

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await authManager.signInWithApple(credential: credential)
                }
            }
        case .failure(let error):
            authManager.error = error.localizedDescription
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: FPSpacing.md) {
            ZStack {
                Circle()
                    .fill(FPColors.primary.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(FPColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FPTypography.headline)
                    .foregroundColor(FPColors.textPrimary)

                Text(subtitle)
                    .font(FPTypography.footnote)
                    .foregroundColor(FPColors.textSecondary)
            }

            Spacer()
        }
        .padding(FPSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FPRadius.md)
                .fill(FPColors.surface.opacity(0.8))
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
