import SwiftUI

/// Harbor's visual language: a deep "harbor at night" palette with a teal
/// accent, generous rounding and soft depth. Centralized so the whole app
/// reads as one system in light and dark mode.
enum Theme {
    static let corner: CGFloat = 16
    static let smallCorner: CGFloat = 10
    static let spacing: CGFloat = 14

    // Accent gradient used on primary actions and highlights.
    static let accent = Color("AccentColor")
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x16BDCA), Color(hex: 0x2E7DF6)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static let monoFont = Font.system(.body, design: .monospaced)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension HostColor {
    var color: Color {
        switch self {
        case .teal: return Color(hex: 0x16BDCA)
        case .blue: return Color(hex: 0x2E7DF6)
        case .purple: return Color(hex: 0x8B5CF6)
        case .pink: return Color(hex: 0xEC4899)
        case .orange: return Color(hex: 0xF59E0B)
        case .green: return Color(hex: 0x22C55E)
        case .red: return Color(hex: 0xEF4444)
        case .gray: return Color(hex: 0x8792A2)
        }
    }
}

/// A rounded, subtly bordered surface used for cards throughout the app.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .harborGlass(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}
