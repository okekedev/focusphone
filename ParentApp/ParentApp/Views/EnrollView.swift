import SwiftUI
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct EnrollView: View {
    @State private var enrollmentToken: EnrollmentToken?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FPColors.background.ignoresSafeArea()

                VStack(spacing: FPSpacing.lg) {
                    if let token = enrollmentToken {
                        enrollmentContent(token: token)
                    } else {
                        generateContent
                    }
                }
                .padding(FPSpacing.lg)
            }
            .navigationTitle("Add Device")
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    // MARK: - Generate Content

    private var generateContent: some View {
        VStack(spacing: FPSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(FPColors.primary.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(FPColors.primary.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "qrcode")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(FPColors.primary)
            }

            VStack(spacing: FPSpacing.sm) {
                Text("Add a Device")
                    .font(FPTypography.title)
                    .foregroundColor(FPColors.textPrimary)

                Text("Generate a QR code to enroll an iPhone or iPad into FocusPhone management")
                    .font(FPTypography.subheadline)
                    .foregroundColor(FPColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FPSpacing.lg)
            }

            Spacer()

            // Generate button
            Button {
                Task { await generateToken() }
            } label: {
                HStack(spacing: FPSpacing.sm) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus")
                    }
                    Text("Generate QR Code")
                }
            }
            .buttonStyle(FPPrimaryButtonStyle())
            .disabled(isLoading)
        }
    }

    // MARK: - Enrollment Content

    private func enrollmentContent(token: EnrollmentToken) -> some View {
        ScrollView {
            VStack(spacing: FPSpacing.lg) {
                // QR Code card
                FPCard(padding: FPSpacing.lg) {
                    VStack(spacing: FPSpacing.md) {
                        if let qrImage = generateQRCode(from: token.enrollmentURL) {
                            #if os(iOS)
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                            #else
                            Image(nsImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                            #endif
                        }

                        VStack(spacing: FPSpacing.xs) {
                            Text("Scan to Enroll")
                                .font(FPTypography.title2)
                                .foregroundColor(FPColors.textPrimary)

                            Text("Point the iPhone camera at this QR code")
                                .font(FPTypography.subheadline)
                                .foregroundColor(FPColors.textSecondary)
                        }
                    }
                }

                // Instructions
                FPCard {
                    VStack(alignment: .leading, spacing: FPSpacing.md) {
                        Text("How to Enroll")
                            .font(FPTypography.headline)
                            .foregroundColor(FPColors.textPrimary)

                        InstructionStep(number: 1, text: "Open the Camera app on the iPhone")
                        InstructionStep(number: 2, text: "Point at the QR code above")
                        InstructionStep(number: 3, text: "Tap the notification that appears")
                        InstructionStep(number: 4, text: "Go to Settings → General → VPN & Device Management")
                        InstructionStep(number: 5, text: "Tap the profile and select \"Install\"")
                    }
                }

                // Expiry info
                HStack(spacing: FPSpacing.xs) {
                    Image(systemName: "clock")
                        .foregroundColor(FPColors.textTertiary)
                    Text("Expires: \(token.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(FPTypography.footnote)
                        .foregroundColor(FPColors.textTertiary)
                }

                // New code button
                Button {
                    enrollmentToken = nil
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Generate New Code")
                    }
                }
                .buttonStyle(FPSecondaryButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func generateToken() async {
        isLoading = true
        error = nil

        do {
            enrollmentToken = try await APIClient.shared.createEnrollmentToken()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - QR Code Generation

    #if os(iOS)
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
    #else
    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    #endif
}

// MARK: - Instruction Step

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: FPSpacing.md) {
            ZStack {
                Circle()
                    .fill(FPColors.primary)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(FPTypography.caption.weight(.bold))
                    .foregroundColor(.white)
            }

            Text(text)
                .font(FPTypography.subheadline)
                .foregroundColor(FPColors.textSecondary)

            Spacer()
        }
    }
}

#Preview {
    EnrollView()
        .environmentObject(AuthManager())
}
