import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
                .tag(0)

            EnrollView()
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
        #else
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Devices", systemImage: "iphone")
                    .tag(0)
                Label("Add Device", systemImage: "qrcode")
                    .tag(1)
                Label("Account", systemImage: "person.circle")
                    .tag(2)
            }
            .navigationTitle("FocusPhone")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case 0:
                DevicesView()
            case 1:
                EnrollView()
            case 2:
                AccountView()
            default:
                DevicesView()
            }
        }
        .tint(FPColors.primary)
        #endif
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
