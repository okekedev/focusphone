import SwiftUI
import MapKit

struct DevicesView: View {
    @State private var devices: [Device] = []
    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedDevice: Device?
    @State private var showingMap = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading devices...")
                } else if devices.isEmpty {
                    EmptyDevicesView()
                } else {
                    devicesList
                }
            }
            .navigationTitle("Your Devices")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingMap) {
                if let device = selectedDevice {
                    DeviceMapView(device: device)
                }
            }
        }
    }

    private var devicesList: some View {
        List {
            ForEach(devices) { device in
                DeviceRow(
                    device: device,
                    profile: profiles.first { $0.id == device.profileId },
                    onFindDevice: {
                        selectedDevice = device
                        showingMap = true
                    }
                )
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let devicesTask = APIClient.shared.getDevices()
            async let profilesTask = APIClient.shared.getProfiles()

            devices = try await devicesTask
            profiles = try await profilesTask
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct DeviceRow: View {
    let device: Device
    let profile: Profile?
    let onFindDevice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.model)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(device.status == "managed" ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
            }

            Divider()

            // Status row
            HStack(spacing: 16) {
                // Battery
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                    Text(batteryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Last check-in
                HStack(spacing: 4) {
                    Image(systemName: device.isOnline ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundColor(device.isOnline ? .green : .orange)
                    Text(lastCheckinText)
                        .font(.caption)
                        .foregroundColor(device.isOnline ? .secondary : .orange)
                }

                Spacer()

                // Profile
                if let profile {
                    Text(profile.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
            }

            // Find Device button
            Button(action: onFindDevice) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Find Device")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var batteryIcon: String {
        guard let level = device.batteryLevel else { return "battery.0" }
        switch level {
        case 0..<20: return "battery.25"
        case 20..<50: return "battery.50"
        case 50..<80: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        guard let level = device.batteryLevel else { return .gray }
        if level < 20 { return .red }
        if level < 50 { return .yellow }
        return .green
    }

    private var batteryText: String {
        guard let level = device.batteryLevel else { return "--" }
        return "\(Int(level))%"
    }

    private var lastCheckinText: String {
        guard let date = device.lastCheckin else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Devices Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap \"Add Device\" to enroll your first device")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DeviceMapView: View {
    let device: Device
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if device.hasLocation, let lat = device.latitude, let lon = device.longitude {
                    Map {
                        Marker(device.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    .mapStyle(.standard)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))

                        Text("No Location Data")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Location will appear after the device checks in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(iOS)
                    .background(Color(.systemGroupedBackground))
                    #else
                    .background(Color(nsColor: .windowBackgroundColor))
                    #endif
                }
            }
            .navigationTitle(device.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DevicesView()
        .environmentObject(AuthManager())
}
