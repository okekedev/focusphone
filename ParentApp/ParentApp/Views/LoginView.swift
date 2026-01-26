import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "iphone")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.blue.opacity(0.1))
                    )

                Text("FocusPhone")
                    .font(.system(size: 34, weight: .bold))

                Text("Keep your family connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 60)

            Spacer()

            // Sign in buttons
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)

                #if DEBUG
                Button {
                    // Dev mode sign in
                    Task {
                        APIClient.shared.setToken("dev-token")
                        APIClient.shared.setProvider("apple")
                        await authManager.checkAuthStatus()
                    }
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                        Text("Continue in Dev Mode")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            Text("By continuing, you agree to our Terms of Service")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authManager.error ?? "Unknown error occurred")
        }
        .onChange(of: authManager.error) { _, newValue in
            showError = newValue != nil
        }
    }

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

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
