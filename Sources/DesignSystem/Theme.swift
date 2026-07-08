import SwiftUI
import UIKit

extension Color {
    init(hex: String) { self = (RGBAColor(hex: hex) ?? .black).color }
}

/// Design tokens for the whole app. Colors are dynamic — they resolve to the
/// light or dark value based on the current interface style, so the entire UI
/// chrome adapts automatically. (The canvas/export is model-driven and never
/// changes with the app theme.)
enum Theme {
    /// A color that resolves per light/dark interface style.
    private static func dyn(_ light: String, _ dark: String) -> Color {
        let l = (RGBAColor(hex: light) ?? .white).uiColor
        let d = (RGBAColor(hex: dark) ?? .black).uiColor
        return Color(UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }

    // Brand
    static let accent      = dyn("#675CEA", "#8B80FF")
    static let accentDeep  = dyn("#4B3FD1", "#6D5FF0")
    static let accentSoft  = dyn("#EEECFF", "#2A2550")

    // Surfaces
    static let background   = dyn("#F5F6F8", "#0E1017")
    static let surface      = dyn("#FFFFFF", "#191C27")
    static let surfaceSunk  = dyn("#EDEEF2", "#242838")
    static let elevated     = dyn("#FFFFFF", "#1F2330")

    // Ink
    static let ink          = dyn("#15182A", "#F2F3F7")
    static let inkSecondary = dyn("#5B6072", "#A7ACC0")
    static let inkTertiary  = dyn("#9AA0B2", "#6C7285")
    static let separator    = dyn("#E4E6EC", "#2C3142")

    /// Always-dark pill for toasts/HUDs (white text reads on it in both themes).
    static let hud          = dyn("#1C1F2B", "#2C3142")

    // Metrics
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 34
    }
}

/// The user's app-theme preference (persisted via @AppStorage("appTheme")).
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" }
    }
    var symbol: String {
        switch self { case .system: return "circle.lefthalf.filled"; case .light: return "sun.max.fill"; case .dark: return "moon.fill" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

// MARK: - Reusable surfaces

extension View {
    /// A soft card surface used for panels and gallery tiles.
    func cardSurface(radius: CGFloat = Theme.Radius.md) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
    }
}

/// Primary filled capsule button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
