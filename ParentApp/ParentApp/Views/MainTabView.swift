import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var enrollmentManager = EnrollmentManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
                .tag(0)

            EnrollView()
                .environmentObject(enrollmentManager)
                .tabItem {
                    Label("Add Device", systemImage: "qrcode")
                }
                .tag(1)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(2)
        }
        .tint(FPColors.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
