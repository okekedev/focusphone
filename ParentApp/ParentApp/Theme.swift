import SwiftUI

// MARK: - FocusPhone Design System

/// Brand colors for FocusPhone
/// A calming, trustworthy palette for digital wellness
struct FPColors {
    // Primary - Soft indigo for trust and calm
    static let primary = Color(hex: "6366F1")
    static let primaryLight = Color(hex: "818CF8")
    static let primaryDark = Color(hex: "4F46E5")

    // Secondary - Warm teal for growth and balance
    static let secondary = Color(hex: "14B8A6")
    static let secondaryLight = Color(hex: "2DD4BF")

    // Accent - Soft amber for warmth and attention
    static let accent = Color(hex: "F59E0B")
    static let accentLight = Color(hex: "FBBF24")

    // Success/Status
    static let success = Color(hex: "10B981")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")

    // Neutrals
    static let background = Color(hex: "F8FAFC")
    static let surface = Color.white
    static let surfaceSecondary = Color(hex: "F1F5F9")
    static let textPrimary = Color(hex: "0F172A")
    static let textSecondary = Color(hex: "64748B")
    static let textTertiary = Color(hex: "94A3B8")
    static let border = Color(hex: "E2E8F0")

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color.white, Color(hex: "F8FAFC")],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Typography styles
struct FPTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
}

/// Spacing constants
struct FPSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner radius constants
struct FPRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Components

/// Primary button style
struct FPPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FPTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.primaryGradient)
                    .shadow(color: FPColors.primary.opacity(0.3), radius: 8, y: 4)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary button style
struct FPSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FPTypography.headline)
            .foregroundColor(FPColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .fill(FPColors.primary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FPRadius.md)
                    .stroke(FPColors.primary.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Card container
struct FPCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = FPSpacing.md

    init(padding: CGFloat = FPSpacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: FPRadius.lg)
                    .fill(FPColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FPRadius.lg)
                    .stroke(FPColors.border, lineWidth: 1)
            )
    }
}

/// Status badge
struct FPStatusBadge: View {
    let status: String

    private var config: (color: Color, icon: String) {
        switch status.lowercased() {
        case "managed": return (FPColors.success, "checkmark.circle.fill")
        case "enrolled": return (FPColors.primary, "arrow.triangle.2.circlepath")
        case "pending": return (FPColors.warning, "clock.fill")
        case "offline": return (FPColors.textTertiary, "wifi.slash")
        default: return (FPColors.textTertiary, "questionmark.circle")
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(status.capitalized)
                .font(FPTypography.caption)
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(config.color.opacity(0.12))
        )
    }
}

/// Empty state view
struct FPEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: FPSpacing.lg) {
            ZStack {
                Circle()
                    .fill(FPColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(FPColors.primary.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(FPColors.primary)
            }

            VStack(spacing: FPSpacing.sm) {
                Text(title)
                    .font(FPTypography.title2)
                    .foregroundColor(FPColors.textPrimary)

                Text(subtitle)
                    .font(FPTypography.subheadline)
                    .foregroundColor(FPColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FPSpacing.xl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus")
                        Text(actionTitle)
                    }
                }
                .buttonStyle(FPPrimaryButtonStyle())
                .padding(.horizontal, FPSpacing.xxl)
                .padding(.top, FPSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FPColors.background)
    }
}

/// Loading view with shimmer
struct FPLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: FPSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(FPColors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(FPColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }

            Text("Loading...")
                .font(FPTypography.subheadline)
                .foregroundColor(FPColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FPColors.background)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Preview

#Preview("Components") {
    VStack(spacing: 20) {
        FPCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(FPTypography.headline)
                Text("Card content goes here")
                    .font(FPTypography.body)
                    .foregroundColor(FPColors.textSecondary)
            }
        }
        .padding()

        HStack {
            FPStatusBadge(status: "managed")
            FPStatusBadge(status: "pending")
            FPStatusBadge(status: "offline")
        }

        Button("Primary Button") {}
            .buttonStyle(FPPrimaryButtonStyle())
            .padding()

        Button("Secondary Button") {}
            .buttonStyle(FPSecondaryButtonStyle())
            .padding()
    }
    .background(FPColors.background)
}
