import SwiftUI
import MapKit

struct DevicesView: View {
    @State private var devices: [Device] = []
    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedDevice: Device?
    @State private var showingMap = false
    @State private var showingProfilePicker = false
    @State private var deviceForProfile: Device?

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                Group {
                    if isLoading {
                        FPLoadingView()
                    } else if devices.isEmpty {
                        FPEmptyState(
                            icon: "iphone.slash",
                            title: "No Devices Yet",
                            subtitle: "Add a device to start managing it. Tap the \"Add Device\" tab to generate a QR code.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        devicesList
                    }
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(FPColors.primary)
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
            .sheet(isPresented: $showingProfilePicker) {
                if let device = deviceForProfile {
                    ProfilePickerView(device: device, profiles: profiles) {
                        Task { await loadData() }
                    }
                }
            }
        }
    }

    private var devicesList: some View {
        ScrollView {
            LazyVStack(spacing: FPSpacing.md) {
                ForEach(devices) { device in
                    DeviceCard(
                        device: device,
                        profile: profiles.first { $0.id == device.profileId },
                        onFindDevice: {
                            selectedDevice = device
                            showingMap = true
                        },
                        onChangeProfile: {
                            deviceForProfile = device
                            showingProfilePicker = true
                        }
                    )
                }
            }
            .padding(FPSpacing.md)
        }
    }

    private func loadData() async {
        isLoading = devices.isEmpty
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

// MARK: - Device Card

struct DeviceCard: View {
    let device: Device
    let profile: Profile?
    let onFindDevice: () -> Void
    let onChangeProfile: () -> Void

    var body: some View {
        FPCard(padding: 0) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: FPSpacing.md) {
                    // Device icon
                    ZStack {
                        RoundedRectangle(cornerRadius: FPRadius.md)
                            .fill(FPColors.primaryGradient)
                            .frame(width: 56, height: 56)

                        Image(systemName: "iphone")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(FPTypography.headline)
                            .foregroundColor(FPColors.textPrimary)

                        Text(device.model)
                            .font(FPTypography.subheadline)
                            .foregroundColor(FPColors.textSecondary)
                    }

                    Spacer()

                    FPStatusBadge(status: device.status)
                }
                .padding(FPSpacing.md)

                Divider()
                    .padding(.horizontal, FPSpacing.md)

                // Stats row
                HStack(spacing: 0) {
                    // Battery
                    StatItem(
                        icon: batteryIcon,
                        value: batteryText,
                        label: "Battery",
                        color: batteryColor
                    )

                    Divider()
                        .frame(height: 40)

                    // Last seen
                    StatItem(
                        icon: device.isOnline ? "checkmark.circle.fill" : "clock",
                        value: lastCheckinText,
                        label: device.isOnline ? "Online" : "Last seen",
                        color: device.isOnline ? FPColors.success : FPColors.textTertiary
                    )

                    Divider()
                        .frame(height: 40)

                    // Profile
                    StatItem(
                        icon: "shield.fill",
                        value: profile?.name ?? "None",
                        label: "Profile",
                        color: FPColors.primary
                    )
                }
                .padding(.vertical, FPSpacing.md)

                Divider()
                    .padding(.horizontal, FPSpacing.md)

                // Actions
                HStack(spacing: FPSpacing.sm) {
                    Button(action: onFindDevice) {
                        HStack(spacing: FPSpacing.xs) {
                            Image(systemName: "location.fill")
                            Text("Find")
                        }
                        .font(FPTypography.subheadline.weight(.medium))
                        .foregroundColor(FPColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FPSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: FPRadius.sm)
                                .fill(FPColors.primary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onChangeProfile) {
                        HStack(spacing: FPSpacing.xs) {
                            Image(systemName: "shield")
                            Text("Profile")
                        }
                        .font(FPTypography.subheadline.weight(.medium))
                        .foregroundColor(FPColors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FPSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: FPRadius.sm)
                                .fill(FPColors.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(FPSpacing.md)
            }
        }
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
        guard let level = device.batteryLevel else { return FPColors.textTertiary }
        if level < 20 { return FPColors.error }
        if level < 50 { return FPColors.warning }
        return FPColors.success
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

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)

                Text(value)
                    .font(FPTypography.subheadline.weight(.semibold))
                    .foregroundColor(FPColors.textPrimary)
            }

            Text(label)
                .font(FPTypography.caption)
                .foregroundColor(FPColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Picker

struct ProfilePickerView: View {
    let device: Device
    let profiles: [Profile]
    let onAssigned: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isAssigning = false
    @State private var selectedProfileId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FPSpacing.md) {
                        // Device info
                        HStack(spacing: FPSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: FPRadius.md)
                                    .fill(FPColors.primary.opacity(0.1))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "iphone")
                                    .foregroundColor(FPColors.primary)
                            }

                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(FPTypography.headline)
                                Text(device.model)
                                    .font(FPTypography.subheadline)
                                    .foregroundColor(FPColors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(FPSpacing.md)
                        .background(FPColors.surface)
                        .cornerRadius(FPRadius.md)

                        // Profiles
                        ForEach(profiles) { profile in
                            ProfileOptionCard(
                                profile: profile,
                                isSelected: selectedProfileId == profile.id,
                                onSelect: { selectedProfileId = profile.id }
                            )
                        }

                        // Assign button
                        if let profileId = selectedProfileId {
                            Button {
                                Task {
                                    isAssigning = true
                                    try? await APIClient.shared.assignProfile(profileId: profileId, deviceId: device.id)
                                    isAssigning = false
                                    onAssigned()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    if isAssigning {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text("Apply Profile")
                                }
                            }
                            .buttonStyle(FPPrimaryButtonStyle())
                            .disabled(isAssigning)
                            .padding(.top, FPSpacing.md)
                        }
                    }
                    .padding(FPSpacing.md)
                }
            }
            .navigationTitle("Choose Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ProfileOptionCard: View {
    let profile: Profile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FPSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? FPColors.primary : FPColors.surfaceSecondary)
                        .frame(width: 44, height: 44)

                    Image(systemName: "shield.fill")
                        .foregroundColor(isSelected ? .white : FPColors.textSecondary)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(FPTypography.headline)
                        .foregroundColor(FPColors.textPrimary)

                    Text(profile.description)
                        .font(FPTypography.footnote)
                        .foregroundColor(FPColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FPColors.primary)
                        .font(.title2)
                }
            }
            .padding(FPSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: FPRadius.md)
                            .stroke(isSelected ? FPColors.primary : FPColors.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Map View

struct DeviceMapView: View {
    let device: Device
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if device.hasLocation, let lat = device.latitude, let lon = device.longitude {
                    Map {
                        Marker(device.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(FPColors.primary)
                    }
                    .mapStyle(.standard)
                } else {
                    FPEmptyState(
                        icon: "location.slash",
                        title: "No Location Data",
                        subtitle: "Location will appear after the device checks in with location services enabled."
                    )
                }
            }
            .navigationTitle(device.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DevicesView()
        .environmentObject(AuthManager())
}
