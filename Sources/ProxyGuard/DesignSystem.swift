import SwiftUI

// MARK: - Design Tokens
enum DesignSystem {

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24

    // Corner Radius
    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 10
    static let radiusL: CGFloat = 16
    static let radiusXL: CGFloat = 24

    // Icon Size
    static let iconS: CGFloat = 14
    static let iconM: CGFloat = 18
    static let iconL: CGFloat = 24

    // Layout
    static let menuMinWidth: CGFloat = 320
    static let menuIdealWidth: CGFloat = 340
    static let menuMaxWidth: CGFloat = 400
    static let settingsWidth: CGFloat = 600
    static let settingsHeight: CGFloat = 520

    // Animation
    static let animationFast: Double = 0.15
    static let animationNormal: Double = 0.25
    static let animationSlow: Double = 0.35

    static var spring: Animation {
        .spring(response: 0.35, dampingFraction: 0.75)
    }

    static var easeInOut: Animation {
        .easeInOut(duration: animationNormal)
    }
}

// MARK: - Color Palette
extension Color {

    // Brand Gradients (The "Pro" Look)
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let activeGradient = LinearGradient(
        colors: [Color(hex: "00c6ff"), Color(hex: "0072ff")], // Blue
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let pausedGradient = LinearGradient(
        colors: [Color(hex: "f12711"), Color(hex: "f5af19")], // Orange/Red
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Neon Accents
    static let neonBlue = Color(hex: "00f2ea")
    static let neonGreen = Color(hex: "00f260")
    static let neonRed = Color(hex: "ff0055")
    static let neonAmber = Color(hex: "ff9900")

    // Semantic Colors
    static let semanticSuccess = neonGreen
    static let semanticWarning = neonAmber
    static let semanticError = neonRed
    static let semanticInfo = neonBlue

    // Backgrounds
    static let glassBackground = Color.black.opacity(0.3)
    static let glassBorder = Color.white.opacity(0.15)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.4)
    
    // Hex Init Helper
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
extension View {
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(size: size, weight: weight, design: design))
    }
}
