import SwiftUI
import SwiftData

@main
struct FocusPhoneApp: App {
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
            RootView()
                .environmentObject(apiClient)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        Group {
            if apiClient.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }

            if apiClient.currentUser?.role == "admin" {
                AdminView()
                    .tabItem {
                        Label("Admin", systemImage: "person.badge.shield.checkmark")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Auth View

struct AuthView: View {
    @EnvironmentObject var apiClient: APIClient

    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "iphone.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("FocusPhone")
                        .font(.largeTitle.bold())

                    Text("Take back control of your device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    if !isLogin {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(isLogin ? .password : .newPassword)
                        .textFieldStyle(.roundedBorder)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await authenticate() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isLogin ? "Sign In" : "Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button {
                        isLogin.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isLogin ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                            .font(.footnote)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private func authenticate() async {
        isLoading = true
        errorMessage = nil

        do {
            if isLogin {
                _ = try await apiClient.login(email: email, password: password)
            } else {
                _ = try await apiClient.register(email: email, password: password, name: name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var devices: [APIDevice] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome card
                    welcomeCard

                    // Quick actions
                    quickActionsSection

                    // Device status
                    deviceStatusSection
                }
                .padding()
            }
            .navigationTitle("Home")
            .task {
                await loadDevices()
            }
            .refreshable {
                await loadDevices()
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome, \(apiClient.currentUser?.name ?? "User")")
                .font(.title2.bold())

            Text(devices.isEmpty
                 ? "Enroll a device to get started"
                 : "\(devices.count) device\(devices.count == 1 ? "" : "s") managed")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Enroll Device",
                    icon: "plus.circle",
                    color: .blue
                ) {
                    // TODO: Navigate to enrollment
                }

                QuickActionButton(
                    title: "View Profiles",
                    icon: "list.bullet.rectangle",
                    color: .purple
                ) {
                    // TODO: Navigate to profiles
                }
            }
        }
    }

    private var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Devices")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "iphone.slash",
                    description: Text("Enroll a device to manage it")
                )
            } else {
                ForEach(devices) { device in
                    DeviceRow(device: device)
                }
            }
        }
    }

    private func loadDevices() async {
        isLoading = true
        do {
            devices = try await apiClient.getDevices()
        } catch {
            print("Failed to load devices: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: APIDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)

                Text("\(device.model) - iOS \(device.osVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: device.status)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
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
        Text(status.capitalized)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Placeholder Views

struct DevicesView: View {
    var body: some View {
        NavigationStack {
            Text("Devices")
                .navigationTitle("Devices")
        }
    }
}

struct AdminView: View {
    var body: some View {
        NavigationStack {
            Text("Admin Panel")
                .navigationTitle("Admin")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = apiClient.currentUser {
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: user.role.capitalized)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        apiClient.logout()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
