import SwiftUI
import SwiftData

@main
struct FocusPhoneAdminApp: App {
    @StateObject private var apiClient = APIClient.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Device.self,
            RestrictionProfile.self,
            MDMCommand.self,
            EnrollmentToken.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AdminRootView()
                .environmentObject(apiClient)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}

// MARK: - Admin Root View

struct AdminRootView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        Group {
            if apiClient.isAuthenticated {
                AdminDashboardView()
            } else {
                AdminLoginView()
            }
        }
    }
}

// MARK: - Admin Login View

struct AdminLoginView: View {
    @EnvironmentObject var apiClient: APIClient

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 12) {
                Image(systemName: "iphone.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("FocusPhone Admin")
                    .font(.largeTitle.bold())

                Text("Manage devices and restrictions")
                    .foregroundStyle(.secondary)
            }

            // Login Form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await login() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .keyboardShortcut(.return)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func login() async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await apiClient.login(email: email, password: password)
            if user.role != "admin" {
                apiClient.logout()
                errorMessage = "Admin access required"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    @State private var selectedSection: AdminSection = .dashboard

    var body: some View {
        NavigationSplitView {
            AdminSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView()
            case .devices:
                AdminDevicesView()
            case .profiles:
                ProfilesView()
            case .users:
                UsersView()
            case .enrollment:
                EnrollmentView()
            case .settings:
                AdminSettingsView()
            }
        }
    }
}

enum AdminSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case devices = "Devices"
    case profiles = "Profiles"
    case users = "Users"
    case enrollment = "Enrollment"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .devices: return "iphone"
        case .profiles: return "list.bullet.rectangle"
        case .users: return "person.2"
        case .enrollment: return "qrcode"
        case .settings: return "gear"
        }
    }
}

// MARK: - Admin Sidebar

struct AdminSidebar: View {
    @Binding var selection: AdminSection
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        List(selection: $selection) {
            Section("Management") {
                ForEach([AdminSection.dashboard, .devices, .profiles]) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Organization") {
                ForEach([AdminSection.users, .enrollment]) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section {
                Label("Settings", systemImage: "gear")
                    .tag(AdminSection.settings)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                HStack {
                    Image(systemName: "person.circle")
                    VStack(alignment: .leading) {
                        Text(apiClient.currentUser?.name ?? "Admin")
                            .font(.caption.bold())
                        Text(apiClient.currentUser?.email ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        apiClient.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var devices: [APIDevice] = []
    @State private var profiles: [APIProfile] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats cards
                HStack(spacing: 16) {
                    StatCard(
                        title: "Total Devices",
                        value: "\(devices.count)",
                        icon: "iphone",
                        color: .blue
                    )
                    StatCard(
                        title: "Managed",
                        value: "\(devices.filter { $0.status == "managed" }.count)",
                        icon: "checkmark.shield",
                        color: .green
                    )
                    StatCard(
                        title: "Pending",
                        value: "\(devices.filter { $0.status == "pending" }.count)",
                        icon: "clock",
                        color: .orange
                    )
                    StatCard(
                        title: "Profiles",
                        value: "\(profiles.count)",
                        icon: "list.bullet.rectangle",
                        color: .purple
                    )
                }

                // Recent devices
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Devices")
                        .font(.title2.bold())

                    if devices.isEmpty {
                        Text("No devices enrolled yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        DeviceTableView(devices: devices)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .task {
            await loadData()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            async let devicesTask = apiClient.getDevices()
            async let profilesTask = apiClient.getProfiles()
            devices = try await devicesTask
            profiles = try await profilesTask
        } catch {
            print("Failed to load data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Device Table View

struct DeviceTableView: View {
    let devices: [APIDevice]

    var body: some View {
        Table(devices) {
            TableColumn("Device") { device in
                HStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .fontWeight(.medium)
                        Text(device.model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            TableColumn("iOS Version") { device in
                Text(device.osVersion)
            }

            TableColumn("Status") { device in
                StatusBadgeMac(status: device.status)
            }

            TableColumn("Last Check-in") { device in
                if let date = device.lastCheckin {
                    Text(date, style: .relative)
                } else {
                    Text("-")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Status Badge (macOS)

struct StatusBadgeMac: View {
    let status: String

    var color: Color {
        switch status {
        case "managed": return .green
        case "enrolled": return .blue
        case "pending": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.capitalized)
                .font(.caption)
        }
    }
}

// MARK: - Placeholder Views

struct AdminDevicesView: View {
    var body: some View {
        Text("Devices Management")
            .navigationTitle("Devices")
    }
}

struct ProfilesView: View {
    var body: some View {
        Text("Profiles Management")
            .navigationTitle("Profiles")
    }
}

struct UsersView: View {
    var body: some View {
        Text("Users Management")
            .navigationTitle("Users")
    }
}

struct EnrollmentView: View {
    var body: some View {
        Text("Enrollment Management")
            .navigationTitle("Enrollment")
    }
}

struct AdminSettingsView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        Form {
            Section("Server") {
                LabeledContent("API Endpoint", value: "https://your-mdm-server.com")
            }

            Section("Account") {
                if let user = apiClient.currentUser {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Role", value: user.role.capitalized)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
