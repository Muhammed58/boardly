import CoreGraphics

/// The reusable "look" of a canvas — background + screenshot styling. Shared by
/// the built-in styles, user-saved presets, and the brand kit.
struct CanvasLook: Codable, Equatable {
    var background: BackgroundStyle
    var frame: DeviceFrameKind = .none
    var shadow: ShadowStyle = .medium
    var cornerRadius: Double = 0.05
    var padding: Double = 0.12
    var tiltX: Double = 0
    var tiltY: Double = 0

    func apply(to model: EditorModel) { model.edit { applyTo(&$0) } }

    /// A copy of `base` reduced to its screenshot with this look — for thumbnails.
    func previewCanvas(base: EditorCanvas) -> EditorCanvas {
        var canvas = base
        canvas.layers = base.layers.filter { $0.isScreenshot }
        canvas.vignette = nil; canvas.grain = nil; canvas.watermark = nil
        applyTo(&canvas)
        return canvas
    }

    func applyTo(_ canvas: inout EditorCanvas) {
        canvas.background = background
        guard let id = canvas.primaryScreenshot?.id, var layer = canvas[id],
              case .screenshot(var s) = layer.content else { return }
        s.frame = frame; s.shadow = shadow; s.cornerRadius = cornerRadius
        layer.content = .screenshot(s)
        let size = 1 - 2 * padding
        layer.transform.size = CGSize(width: size, height: size)
        layer.transform.center = CGPoint(x: 0.5, y: 0.5)
        layer.transform.rotationX = tiltX
        layer.transform.rotationY = tiltY
        layer.transform.rotation = 0
        canvas[id] = layer
    }

    /// Capture the current canvas as a look.
    static func from(_ canvas: EditorCanvas) -> CanvasLook {
        var look = CanvasLook(background: canvas.background)
        if case .screenshot(let s)? = canvas.primaryScreenshot?.content {
            look.frame = s.frame; look.shadow = s.shadow; look.cornerRadius = s.cornerRadius
        }
        if let t = canvas.primaryScreenshot?.transform {
            look.padding = Double((1 - t.size.width) / 2)
            look.tiltX = t.rotationX; look.tiltY = t.rotationY
        }
        return look
    }
}

/// A built-in complete look.
struct CompleteStyle: Identifiable {
    let id: String
    let name: String
    let look: CanvasLook

    init(_ id: String, _ name: String, background: BackgroundStyle, frame: DeviceFrameKind = .none,
         shadow: ShadowStyle = .medium, cornerRadius: Double = 0.05, padding: Double = 0.12,
         tiltX: Double = 0, tiltY: Double = 0) {
        self.id = id; self.name = name
        self.look = CanvasLook(background: background, frame: frame, shadow: shadow,
                               cornerRadius: cornerRadius, padding: padding, tiltX: tiltX, tiltY: tiltY)
    }
}

enum StyleCatalog {
    private static func hex(_ s: String) -> RGBAColor { RGBAColor(hex: s) ?? .black }

    static let all: [CompleteStyle] = [
        CompleteStyle("clean", "Clean", background: .solid(hex("#F4F5F7")), shadow: .soft, padding: 0.1),
        CompleteStyle("violet", "Violet", background: BackgroundPresets.gradients[0].style, shadow: .strong, padding: 0.14),
        CompleteStyle("aurora", "Aurora", background: BackgroundPresets.meshes[0].style, frame: .browserLight, shadow: .strong, padding: 0.12),
        CompleteStyle("sunset", "Sunset", background: BackgroundPresets.gradients[1].style, shadow: .strong, cornerRadius: 0.06, padding: 0.14),
        CompleteStyle("tilted", "Tilt", background: BackgroundPresets.meshes[2].style, shadow: .strong, padding: 0.16, tiltX: 0.12, tiltY: -0.16),
        CompleteStyle("mac", "Mac", background: BackgroundPresets.gradients[4].style, frame: .macWindow, shadow: .strong, padding: 0.12),
        CompleteStyle("device", "Device", background: BackgroundPresets.gradients[8].style, frame: .iphone, shadow: .strong, padding: 0.16),
        CompleteStyle("night", "Night", background: BackgroundPresets.gradients[6].style, frame: .windowDark, shadow: .strong, padding: 0.13),
        CompleteStyle("dots", "Dots", background: .pattern(.dots, hex("#B9C0FF"), hex("#EEF0FF")), shadow: .soft, padding: 0.11),
        CompleteStyle("grid", "Grid", background: .pattern(.grid, hex("#C9CEDD"), hex("#F5F6F8")), shadow: .soft, padding: 0.11),
        CompleteStyle("blur", "Blur", background: .blurredScreenshot(radius: 0.06), shadow: .strong, padding: 0.16),
        CompleteStyle("coral", "Coral", background: BackgroundPresets.gradients[10].style, frame: .browserDark, shadow: .strong, padding: 0.12),
    ]

    static func apply(_ style: CompleteStyle, to model: EditorModel) { style.look.apply(to: model) }
    static func previewCanvas(base: EditorCanvas, style: CompleteStyle) -> EditorCanvas { style.look.previewCanvas(base: base) }
}
