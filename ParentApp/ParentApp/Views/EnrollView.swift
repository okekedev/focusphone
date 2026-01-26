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
            VStack(spacing: 24) {
                if let token = enrollmentToken {
                    enrollmentContent(token: token)
                } else {
                    generateContent
                }
            }
            .padding()
            .navigationTitle("Add Device")
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private var generateContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(30)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)

            Text("Add a Device")
                .font(.title)
                .fontWeight(.bold)

            Text("Generate a QR code to enroll your child's iPhone")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                Task { await generateToken() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus")
                    }
                    Text("Generate QR Code")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
    }

    private func enrollmentContent(token: EnrollmentToken) -> some View {
        VStack(spacing: 20) {
            // QR Code
            if let qrImage = generateQRCode(from: token.enrollmentURL) {
                #if os(iOS)
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                #else
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                #endif
            }

            Text("Scan to Enroll")
                .font(.title2)
                .fontWeight(.bold)

            Text("Open Camera on the iPhone and scan this code")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Open Camera on iPhone")
                InstructionRow(number: 2, text: "Point at QR code")
                InstructionRow(number: 3, text: "Tap notification to install")
                InstructionRow(number: 4, text: "Go to Settings → Install Profile")
            }
            .padding()
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .cornerRadius(12)

            Text("Expires: \(token.expiresAt.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                enrollmentToken = nil
            } label: {
                Text("Generate New Code")
                    .foregroundColor(.blue)
            }
        }
    }

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

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    EnrollView()
        .environmentObject(AuthManager())
}
