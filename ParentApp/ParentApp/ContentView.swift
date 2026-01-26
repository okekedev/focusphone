import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                FPLoadingView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        #if os(iOS)
        .preferredColorScheme(.light)
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
