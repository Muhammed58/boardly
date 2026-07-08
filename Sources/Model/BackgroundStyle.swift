import CoreGraphics

/// The canvas backdrop behind the screenshot. `Codable` via automatic
/// synthesis for enums with associated values.
enum BackgroundStyle: Codable, Equatable {
    case solid(RGBAColor)
    /// Evenly-spaced colors along a line at `angle` degrees (0 = left→right).
    case linearGradient(colors: [RGBAColor], angle: Double)
    case radialGradient(colors: [RGBAColor])
    /// An iOS 18 mesh gradient captured as a color grid.
    case mesh(MeshSpec)
    /// A user-imported background image, referenced by id in the ImageStore.
    case image(id: String, fill: Bool)
    /// The screenshot itself, blurred and scaled to fill — a popular look.
    case blurredScreenshot(radius: Double)
    /// A repeating pattern (foreground on background).
    case pattern(BackgroundPattern, RGBAColor, RGBAColor)

    var isGradient: Bool {
        switch self { case .linearGradient, .radialGradient, .mesh: return true; default: return false }
    }
}

/// A mesh gradient defined as a `rows × cols` grid of colors. Points are laid
/// out on an even grid by the renderer (iOS 18 `MeshGradient`).
struct MeshSpec: Codable, Equatable {
    var rows: Int
    var cols: Int
    var colors: [RGBAColor]

    init(rows: Int, cols: Int, colors: [RGBAColor]) {
        self.rows = rows
        self.cols = cols
        self.colors = colors
    }
}

/// A named backdrop the user can pick from the Background panel.
struct BackgroundPreset: Identifiable, Equatable {
    var id: String
    var name: String
    var style: BackgroundStyle
    /// Colors used to draw the swatch in the picker.
    var swatch: [RGBAColor]

    init(id: String, name: String, style: BackgroundStyle, swatch: [RGBAColor]? = nil) {
        self.id = id
        self.name = name
        self.style = style
        self.swatch = swatch ?? BackgroundPreset.swatchColors(for: style)
    }

    static func swatchColors(for style: BackgroundStyle) -> [RGBAColor] {
        switch style {
        case .solid(let c): return [c]
        case .linearGradient(let c, _): return c
        case .radialGradient(let c): return c
        case .mesh(let m): return m.colors
        case .image: return [.init(red: 0.8, green: 0.8, blue: 0.82)]
        case .blurredScreenshot: return [.init(red: 0.6, green: 0.6, blue: 0.7)]
        case .pattern(_, let fg, let bg): return [bg, fg]
        }
    }
}
