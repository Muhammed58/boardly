import CoreGraphics
import UIKit

// Shared style value types used by layer content.

/// Drop shadow behind the screenshot / a layer. Dimensions are fractions of
/// the canvas min-side so shadows scale with output resolution.
struct ShadowStyle: Codable, Equatable {
    var radius: Double
    var opacity: Double
    var offset: CGSize   // fraction of canvas min-side
    var color: RGBAColor

    static let none   = ShadowStyle(radius: 0,     opacity: 0,    offset: .zero, color: .black)
    static let soft   = ShadowStyle(radius: 0.030, opacity: 0.18, offset: CGSize(width: 0, height: 0.012), color: .black)
    static let medium = ShadowStyle(radius: 0.055, opacity: 0.28, offset: CGSize(width: 0, height: 0.022), color: .black)
    static let strong = ShadowStyle(radius: 0.085, opacity: 0.40, offset: CGSize(width: 0, height: 0.038), color: .black)

    var isVisible: Bool { opacity > 0.001 && radius > 0.0001 }
}

/// Device / window chrome wrapped around a screenshot.
enum DeviceFrameKind: String, Codable, CaseIterable, Identifiable {
    case none
    case iphone          // rounded bezel + Dynamic Island
    case ipad
    case macWindow       // titlebar with traffic lights
    case browserLight    // Safari/Chrome style light chrome + URL bar
    case browserDark
    case windowLight     // minimal window, just traffic lights
    case windowDark
    case android         // Android phone bezel
    case watch           // Apple Watch
    case studioDisplay   // desktop display on a stand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .iphone: return "iPhone"
        case .ipad: return "iPad"
        case .macWindow: return "Mac"
        case .browserLight: return "Browser"
        case .browserDark: return "Browser Dark"
        case .windowLight: return "Window"
        case .windowDark: return "Window Dark"
        case .android: return "Android"
        case .watch: return "Watch"
        case .studioDisplay: return "Display"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "rectangle.dashed"
        case .iphone, .ipad: return "iphone"
        case .macWindow: return "macwindow"
        case .browserLight, .browserDark: return "safari"
        case .windowLight, .windowDark: return "macwindow.on.rectangle"
        case .android: return "candybarphone"
        case .watch: return "applewatch"
        case .studioDisplay: return "display"
        }
    }

    var isBrowser: Bool { self == .browserLight || self == .browserDark }
    var isDark: Bool { self == .browserDark || self == .windowDark }
    /// Frames that carry their own status bar area (phone-like).
    var isPhoneLike: Bool { self == .iphone || self == .android }
}

enum TextAlign: String, Codable, CaseIterable {
    case leading, center, trailing

    var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

enum FontFamily: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, mono
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Sans"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }

    func uiFont(size: CGFloat, weight: FontWeight) -> UIFont {
        let w = weight.uiWeight
        switch self {
        case .system:
            return .systemFont(ofSize: size, weight: w)
        case .rounded:
            let base = UIFont.systemFont(ofSize: size, weight: w)
            if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
            return base
        case .serif:
            let base = UIFont.systemFont(ofSize: size, weight: w)
            if let d = base.fontDescriptor.withDesign(.serif) { return UIFont(descriptor: d, size: size) }
            return base
        case .mono:
            return .monospacedSystemFont(ofSize: size, weight: w)
        }
    }
}

enum FontWeight: String, Codable, CaseIterable {
    case regular, medium, semibold, bold, heavy, black

    var uiWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

/// How a redaction obscures the pixels beneath it.
enum RedactionStyle: String, Codable, CaseIterable, Identifiable {
    case blur, pixelate, solid
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .blur: return "Blur"
        case .pixelate: return "Pixelate"
        case .solid: return "Black Box"
        }
    }
    var symbol: String {
        switch self {
        case .blur: return "drop.fill"
        case .pixelate: return "squareshape.split.3x3"
        case .solid: return "rectangle.fill"
        }
    }
}

// MARK: - Additive style enums (new features)

/// Silhouette a screenshot is clipped to.
enum ScreenshotClip: String, Codable, CaseIterable, Identifiable {
    case roundedRect, circle, squircle
    var id: String { rawValue }
    var displayName: String {
        switch self { case .roundedRect: return "Rounded"; case .circle: return "Circle"; case .squircle: return "Squircle" }
    }
}

/// Clean status-bar overlay appearance.
enum StatusBarStyle: String, Codable, CaseIterable, Identifiable {
    case dark, light
    var id: String { rawValue }
    var displayName: String { self == .dark ? "Dark" : "Light" }
    var tint: RGBAColor { self == .dark ? .black : .white }
}

/// Text emphasis behind glyphs.
enum TextHighlight: String, Codable, CaseIterable, Identifiable {
    case marker, underline, box
    var id: String { rawValue }
    var displayName: String {
        switch self { case .marker: return "Marker"; case .underline: return "Underline"; case .box: return "Box" }
    }
}

/// Speech-bubble tail direction.
enum BubbleTail: String, Codable, CaseIterable, Identifiable {
    case bottomLeft, bottomRight, topLeft, topRight, none
    var id: String { rawValue }
}

/// Repeating pattern backdrop.
enum BackgroundPattern: String, Codable, CaseIterable, Identifiable {
    case dots, grid, graph, noise, diagonal
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// A logo/text watermark stamped on export.
struct WatermarkSpec: Codable, Equatable {
    enum Corner: String, Codable, CaseIterable { case bottomRight, bottomLeft, topRight, topLeft, center }
    var text: String = "@boardly"
    var imageID: String? = nil
    var corner: Corner = .bottomRight
    var opacity: Double = 0.6
    var scale: Double = 0.16      // fraction of canvas width
    var color: RGBAColor = .white
}
