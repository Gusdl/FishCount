import SwiftUI

enum AppTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.14, blue: 0.24),
            Color(red: 0.02, green: 0.35, blue: 0.55),
            Color(red: 0.0, green: 0.55, blue: 0.66)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryAccent = Color(red: 0.12, green: 0.71, blue: 0.81)
    static let secondaryAccent = Color(red: 0.18, green: 0.82, blue: 0.67)

    static let glassBackground: Material = .ultraThin
    static let cardStroke = Color.white.opacity(0.12)
    static let mutedText = Color.white.opacity(0.78)
    static let subtleText = Color.white.opacity(0.6)

    static let buttonGradient = LinearGradient(
        colors: [primaryAccent, Color(red: 0.01, green: 0.45, blue: 0.75)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppTheme.glassBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.cardStroke)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
