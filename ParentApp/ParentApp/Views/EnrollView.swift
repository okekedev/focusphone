import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct EnrollView: View {
    @EnvironmentObject var enrollmentManager: EnrollmentManager
    @State private var selectedProfileId: String?
    @State private var showQRCode = false
    @State private var activeSheet: SheetType?

    enum SheetType: Identifiable {
        case privacy, install, remove

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                if showQRCode, let profileId = selectedProfileId {
                    QRCodeDisplayView(
                        profileId: profileId,
                        enrollmentManager: enrollmentManager,
                        onShowPrivacy: { activeSheet = .privacy },
                        onShowInstall: { activeSheet = .install },
                        onShowRemove: { activeSheet = .remove },
                        onBack: { withAnimation { showQRCode = false } }
                    )
                } else {
                    profileSelectionView
                }
            }
            .navigationTitle(showQRCode ? "Scan QR Code" : "Add Device")
            .toolbar {
                if showQRCode {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            withAnimation { showQRCode = false }
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .privacy:
                    PrivacySheet()
                case .install:
                    InstallSheet()
                case .remove:
                    RemoveSheet()
                }
            }
            .alert("Error", isPresented: .constant(enrollmentManager.error != nil)) {
                Button("OK") { enrollmentManager.error = nil }
            } message: {
                Text(enrollmentManager.error ?? "")
            }
        }
    }

    // MARK: - Profile Selection

    private var profileSelectionView: some View {
        ScrollView {
            VStack(spacing: FPSpacing.lg) {
                // Header
                VStack(spacing: FPSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(FPColors.primaryGradient)
                            .frame(width: 72, height: 72)
                            .shadow(color: FPColors.primary.opacity(0.3), radius: 12, y: 4)

                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("Choose a Profile")
                        .font(FPTypography.title2)
                        .foregroundColor(FPColors.textPrimary)

                    Text("Select restrictions for this device")
                        .font(FPTypography.subheadline)
                        .foregroundColor(FPColors.textSecondary)
                }
                .padding(.top, FPSpacing.lg)

                // Profiles
                if enrollmentManager.isLoadingProfiles {
                    FPLoadingView()
                        .frame(height: 200)
                } else if enrollmentManager.profiles.isEmpty {
                    emptyProfilesView
                } else {
                    VStack(spacing: FPSpacing.md) {
                        ForEach(enrollmentManager.profiles) { profile in
                            ProfileSelectionCard(
                                profile: profile,
                                isSelected: selectedProfileId == profile.id,
                                isReady: enrollmentManager.isTokenReady(for: profile.id),
                                hasFailed: enrollmentManager.hasTokenFailed(for: profile.id)
                            ) {
                                selectedProfileId = profile.id
                            }
                        }

                        // Retry button if any tokens failed
                        if !enrollmentManager.failedTokens.isEmpty {
                            Button {
                                Task { await enrollmentManager.reload() }
                            } label: {
                                HStack(spacing: FPSpacing.xs) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(FPTypography.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .tint(FPColors.primary)
                            .padding(.top, FPSpacing.sm)
                        }
                    }
                }

                Spacer(minLength: FPSpacing.xl)

                // Generate button
                Button {
                    withAnimation { showQRCode = true }
                } label: {
                    HStack(spacing: FPSpacing.sm) {
                        Text("Generate QR Code")
                        Image(systemName: "qrcode")
                    }
                }
                .buttonStyle(FPPrimaryButtonStyle())
                .disabled(selectedProfileId == nil || !enrollmentManager.isTokenReady(for: selectedProfileId ?? ""))
                .padding(.bottom, FPSpacing.lg)
            }
            .padding(.horizontal, FPSpacing.lg)
        }
    }

    private var emptyProfilesView: some View {
        VStack(spacing: FPSpacing.md) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 40))
                .foregroundColor(FPColors.textTertiary)

            Text("No Profiles Yet")
                .font(FPTypography.headline)
                .foregroundColor(FPColors.textPrimary)

            Text("Create profiles in the admin portal")
                .font(FPTypography.subheadline)
                .foregroundColor(FPColors.textSecondary)
        }
        .frame(height: 200)
    }
}

// MARK: - QR Code Display View

struct QRCodeDisplayView: View {
    let profileId: String
    @ObservedObject var enrollmentManager: EnrollmentManager
    let onShowPrivacy: () -> Void
    let onShowInstall: () -> Void
    let onShowRemove: () -> Void
    let onBack: () -> Void

    @State private var cachedQRImage: UIImage?
    @State private var isRegenerating = false
    @State private var hasAttemptedAutoRegenerate = false

    private var token: EnrollmentToken? {
        enrollmentManager.token(for: profileId)
    }

    private var profile: Profile? {
        enrollmentManager.profiles.first { $0.id == profileId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FPSpacing.lg) {
                if let token = token, let qrImage = cachedQRImage {
                    validTokenView(token: token, qrImage: qrImage)
                } else if enrollmentManager.hasTokenFailed(for: profileId) {
                    tokenErrorView
                } else if isRegenerating {
                    regeneratingView
                } else {
                    // Token expired or not available - try to regenerate
                    expiredTokenView
                }
            }
            .padding(.horizontal, FPSpacing.lg)
            .padding(.top, FPSpacing.lg)
        }
        .onAppear {
            generateQRCodeIfNeeded()
        }
        .onChange(of: token?.token) { _, _ in
            generateQRCodeIfNeeded()
        }
    }

    private func generateQRCodeIfNeeded() {
        guard let token = token else {
            cachedQRImage = nil
            return
        }

        let urlString = token.enrollmentURL
        // Generate QR code - this is fast enough to do synchronously
        cachedQRImage = QRCodeGenerator.generate(from: urlString)
    }

    private func regenerateToken() {
        isRegenerating = true
        Task {
            await enrollmentManager.regenerateToken(for: profileId)
            isRegenerating = false
        }
    }

    // MARK: - Views

    private func validTokenView(token: EnrollmentToken, qrImage: UIImage) -> some View {
        VStack(spacing: FPSpacing.md) {
            // QR Code
            ZStack {
                RoundedRectangle(cornerRadius: FPRadius.lg)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 20, y: 8)

                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(FPSpacing.md)
            }
            .frame(width: 220, height: 220)

            // Profile badge
            if let profile = profile {
                HStack(spacing: FPSpacing.xs) {
                    Circle()
                        .fill(FPColors.primary)
                        .frame(width: 8, height: 8)
                    Text(profile.name)
                        .font(FPTypography.caption)
                        .foregroundColor(FPColors.textSecondary)
                }
                .padding(.horizontal, FPSpacing.md)
                .padding(.vertical, FPSpacing.xs)
                .background(
                    Capsule()
                        .fill(FPColors.surfaceSecondary)
                )
            }

            // Instruction
            Text("Scan with child's iPhone camera")
                .font(FPTypography.headline)
                .foregroundColor(FPColors.textPrimary)
                .padding(.top, FPSpacing.md)

            // Learn more cards
            learnMoreCards

            // Expiry indicator
            TokenExpiryView(token: token) {
                regenerateToken()
            }
        }
    }

    private var tokenErrorView: some View {
        VStack(spacing: FPSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FPColors.error.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(FPColors.error)
            }

            VStack(spacing: FPSpacing.sm) {
                Text("Token Generation Failed")
                    .font(FPTypography.title3)
                    .foregroundColor(FPColors.textPrimary)

                Text("Unable to create enrollment token. Please check your connection and try again.")
                    .font(FPTypography.subheadline)
                    .foregroundColor(FPColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                regenerateToken()
            } label: {
                HStack(spacing: FPSpacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
            }
            .buttonStyle(FPPrimaryButtonStyle())
        }
        .padding(FPSpacing.xl)
    }

    private var expiredTokenView: some View {
        VStack(spacing: FPSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FPColors.warning.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundColor(FPColors.warning)
            }

            VStack(spacing: FPSpacing.sm) {
                Text("Token Expired")
                    .font(FPTypography.title3)
                    .foregroundColor(FPColors.textPrimary)

                Text("The enrollment token has expired. Generate a new one to continue.")
                    .font(FPTypography.subheadline)
                    .foregroundColor(FPColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                hasAttemptedAutoRegenerate = false  // Reset on manual tap
                regenerateToken()
            } label: {
                HStack(spacing: FPSpacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Generate New Token")
                }
            }
            .buttonStyle(FPPrimaryButtonStyle())
        }
        .padding(FPSpacing.xl)
        .onAppear {
            // Auto-regenerate once if token just expired, but don't loop
            if !hasAttemptedAutoRegenerate {
                hasAttemptedAutoRegenerate = true
                regenerateToken()
            }
        }
    }

    private var regeneratingView: some View {
        VStack(spacing: FPSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .frame(height: 80)

            Text("Generating new token...")
                .font(FPTypography.subheadline)
                .foregroundColor(FPColors.textSecondary)
        }
        .padding(FPSpacing.xl)
    }

    private var learnMoreCards: some View {
        VStack(spacing: FPSpacing.sm) {
            Text("Learn more")
                .font(FPTypography.caption)
                .foregroundColor(FPColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: FPSpacing.sm) {
                LearnMoreCard(
                    icon: "eye.slash",
                    title: "Privacy",
                    subtitle: "What we see",
                    accentColor: FPColors.primary,
                    action: onShowPrivacy
                )

                LearnMoreCard(
                    icon: "arrow.down.doc",
                    title: "Install",
                    subtitle: "Step by step",
                    accentColor: FPColors.secondary,
                    action: onShowInstall
                )

                LearnMoreCard(
                    icon: "arrow.uturn.backward",
                    title: "Remove",
                    subtitle: "How to undo",
                    accentColor: FPColors.textSecondary,
                    action: onShowRemove
                )
            }
        }
        .padding(.top, FPSpacing.md)
    }

}

// MARK: - QR Code Generator (non-MainActor)

private enum QRCodeGenerator {
    static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Token Expiry View

struct TokenExpiryView: View {
    let token: EnrollmentToken
    let onRefresh: () -> Void

    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: FPSpacing.xs) {
            Image(systemName: expiryIcon)
                .foregroundColor(expiryColor)

            Text(expiryText)
                .foregroundColor(expiryColor)

            if token.isExpiringSoon {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .foregroundColor(FPColors.primary)
            }
        }
        .font(FPTypography.caption)
        .padding(.top, FPSpacing.md)
        .onReceive(timer) { _ in
            timeRemaining = token.expiresAt.timeIntervalSinceNow
        }
        .onAppear {
            timeRemaining = token.expiresAt.timeIntervalSinceNow
        }
    }

    private var expiryIcon: String {
        token.isExpiringSoon ? "exclamationmark.circle" : "clock"
    }

    private var expiryColor: Color {
        token.isExpiringSoon ? FPColors.warning : FPColors.textTertiary
    }

    private var expiryText: String {
        if timeRemaining <= 0 {
            return "Expired"
        } else if timeRemaining < 60 {
            return "Expires in \(Int(timeRemaining))s"
        } else {
            return "Expires \(token.expiresAt.formatted(date: .omitted, time: .shortened))"
        }
    }
}

// MARK: - Learn More Card

struct LearnMoreCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FPSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(accentColor)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(FPTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(FPColors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(FPColors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FPColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FPSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .stroke(FPColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Selection Card

struct ProfileSelectionCard: View {
    let profile: Profile
    let isSelected: Bool
    let isReady: Bool
    var hasFailed: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FPSpacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? FPColors.primary : FPColors.border, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(FPColors.primary)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(FPTypography.headline)
                        .foregroundColor(FPColors.textPrimary)

                    Text(profile.description)
                        .font(FPTypography.caption)
                        .foregroundColor(FPColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Status indicator
                if isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(FPColors.success)
                        .font(.system(size: 18))
                } else if hasFailed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(FPColors.warning)
                        .font(.system(size: 18))
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(FPSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .stroke(isSelected ? FPColors.primary : FPColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy Sheet

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FPSpacing.lg) {
                        InfoSection(
                            icon: "checkmark.shield.fill",
                            iconColor: FPColors.success,
                            title: "What We Can See",
                            items: [
                                "Device name & model",
                                "Battery level",
                                "Location (if enabled)",
                                "Installed profiles"
                            ]
                        )

                        InfoSection(
                            icon: "eye.slash.fill",
                            iconColor: FPColors.primary,
                            title: "What We Cannot See",
                            items: [
                                "Messages or calls",
                                "Photos or files",
                                "Browsing history",
                                "App data or passwords"
                            ]
                        )

                        InfoSection(
                            icon: "slider.horizontal.3",
                            iconColor: FPColors.secondary,
                            title: "What Profiles Control",
                            items: [
                                "Camera & Photos access",
                                "Messages & Phone",
                                "Contacts access",
                                "Content restrictions"
                            ]
                        )
                    }
                    .padding(FPSpacing.lg)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FPColors.primary)
                }
            }
            .toolbarBackground(FPColors.background, for: .navigationBar)
        }
        .background(FPColors.background)
    }
}

// MARK: - Install Sheet

struct InstallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FPSpacing.lg) {
                        VStack(spacing: FPSpacing.md) {
                            InstallStep(
                                number: 1,
                                icon: "camera.viewfinder",
                                title: "Scan QR Code",
                                description: "Open Camera app and point at the QR code"
                            )

                            InstallStep(
                                number: 2,
                                icon: "bell.badge",
                                title: "Tap Notification",
                                description: "Tap the banner that appears at the top"
                            )

                            InstallStep(
                                number: 3,
                                icon: "gear",
                                title: "Open Settings",
                                description: "Go to Settings -> Profile Downloaded"
                            )

                            InstallStep(
                                number: 4,
                                icon: "checkmark.circle",
                                title: "Install Profile",
                                description: "Tap Install and enter device passcode"
                            )
                        }

                        HStack(spacing: FPSpacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(FPColors.primary)
                            Text("No data will be erased during installation")
                                .font(FPTypography.footnote)
                                .foregroundColor(FPColors.textSecondary)
                        }
                        .padding(FPSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: FPRadius.md)
                                .fill(FPColors.primary.opacity(0.08))
                        )
                    }
                    .padding(FPSpacing.lg)
                }
            }
            .navigationTitle("How to Install")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FPColors.primary)
                }
            }
            .toolbarBackground(FPColors.background, for: .navigationBar)
        }
        .background(FPColors.background)
    }
}

struct InstallStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: FPSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FPColors.secondary, FPColors.secondaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(FPTypography.headline)
                    .foregroundColor(FPColors.textPrimary)

                Text(description)
                    .font(FPTypography.footnote)
                    .foregroundColor(FPColors.textSecondary)
            }

            Spacer()
        }
        .padding(FPSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FPRadius.md)
                .fill(FPColors.surface)
        )
    }
}

// MARK: - Remove Sheet

struct RemoveSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FPSpacing.lg) {
                        HStack(spacing: FPSpacing.sm) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(FPColors.success)
                            Text("Management can be removed at any time")
                                .font(FPTypography.subheadline)
                                .foregroundColor(FPColors.textPrimary)
                        }
                        .padding(FPSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: FPRadius.md)
                                .fill(FPColors.success.opacity(0.1))
                        )

                        RemoveOption(
                            icon: "slider.horizontal.3",
                            title: "Remove Profile",
                            description: "Keeps all data intact",
                            steps: [
                                "Open Settings",
                                "Go to General -> VPN & Device Management",
                                "Tap the FocusPhone profile",
                                "Tap Remove Management"
                            ],
                            accentColor: FPColors.primary
                        )

                        RemoveOption(
                            icon: "arrow.counterclockwise",
                            title: "Factory Reset",
                            description: "Erases all data from device",
                            steps: [
                                "Open Settings",
                                "Go to General -> Transfer or Reset iPhone",
                                "Tap Erase All Content and Settings",
                                "Confirm and enter passcode"
                            ],
                            accentColor: FPColors.warning
                        )
                    }
                    .padding(FPSpacing.lg)
                }
            }
            .navigationTitle("How to Remove")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FPColors.primary)
                }
            }
            .toolbarBackground(FPColors.background, for: .navigationBar)
        }
        .background(FPColors.background)
    }
}

struct RemoveOption: View {
    let icon: String
    let title: String
    let description: String
    let steps: [String]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FPSpacing.md) {
            HStack(spacing: FPSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FPTypography.headline)
                        .foregroundColor(FPColors.textPrimary)
                    Text(description)
                        .font(FPTypography.caption)
                        .foregroundColor(FPColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: FPSpacing.xs) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: FPSpacing.sm) {
                        Text("\(index + 1)")
                            .font(FPTypography.caption)
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(accentColor.opacity(0.6)))

                        Text(step)
                            .font(FPTypography.subheadline)
                            .foregroundColor(FPColors.textSecondary)
                    }
                }
            }
            .padding(.leading, FPSpacing.xs)
        }
        .padding(FPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FPRadius.md)
                .fill(FPColors.surface)
        )
    }
}

struct InfoSection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: FPSpacing.sm) {
            HStack(spacing: FPSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(FPTypography.headline)
                    .foregroundColor(FPColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: FPSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: FPSpacing.sm) {
                        Circle()
                            .fill(FPColors.textTertiary)
                            .frame(width: 4, height: 4)
                        Text(item)
                            .font(FPTypography.subheadline)
                            .foregroundColor(FPColors.textSecondary)
                    }
                }
            }
            .padding(.leading, FPSpacing.lg + FPSpacing.sm)
        }
        .padding(FPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FPRadius.md)
                .fill(FPColors.surface)
        )
    }
}

// MARK: - Profile Info Sheet

struct ProfileInfoSheet: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FPSpacing.lg) {
                        VStack(spacing: FPSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(FPColors.primary.opacity(0.1))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 24))
                                    .foregroundColor(FPColors.primary)
                            }

                            Text(profile.name)
                                .font(FPTypography.title2)
                                .foregroundColor(FPColors.textPrimary)

                            Text(profile.description)
                                .font(FPTypography.subheadline)
                                .foregroundColor(FPColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, FPSpacing.md)

                        FPCard {
                            VStack(spacing: FPSpacing.md) {
                                ProfilePermissionRow(title: "Camera & Photos", icon: "camera.fill", allowed: profile.allowCamera)
                                Divider()
                                ProfilePermissionRow(title: "Messages", icon: "message.fill", allowed: profile.allowMessages)
                                Divider()
                                ProfilePermissionRow(title: "Phone", icon: "phone.fill", allowed: profile.allowPhone)
                                Divider()
                                ProfilePermissionRow(title: "Contacts", icon: "person.crop.circle.fill", allowed: profile.allowContacts)
                            }
                        }
                    }
                    .padding(FPSpacing.lg)
                }
            }
            .navigationTitle("Profile Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FPColors.primary)
                }
            }
            .toolbarBackground(FPColors.background, for: .navigationBar)
        }
        .background(FPColors.background)
    }
}

struct ProfilePermissionRow: View {
    let title: String
    let icon: String
    let allowed: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(FPColors.primary)
                .frame(width: 24)

            Text(title)
                .font(FPTypography.body)
                .foregroundColor(FPColors.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(allowed ? "Allowed" : "Blocked")
                    .font(FPTypography.subheadline)
            }
            .foregroundColor(allowed ? FPColors.success : FPColors.error)
        }
    }
}

#Preview {
    EnrollView()
        .environmentObject(EnrollmentManager())
}
