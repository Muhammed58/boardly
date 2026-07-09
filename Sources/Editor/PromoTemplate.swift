import CoreGraphics
import Foundation

/// Placement + styling of a text layer in an promo template.
struct TextSpec {
    var center: CGPoint
    var boxSize: CGSize
    var fontSize: Double
    var weight: FontWeight = .heavy
    var family: FontFamily = .system
    var color: RGBAColor = .white
    var align: TextAlign = .center
    var gradient: [RGBAColor]? = nil
    var highlight: TextHighlight? = nil
    var highlightColor: RGBAColor? = nil
    var hasShadow: Bool = false

    func content(_ string: String) -> TextContent {
        var t = TextContent()
        t.string = string; t.fontSize = fontSize; t.weight = weight; t.family = family
        t.color = color; t.align = align; t.gradient = gradient
        t.highlight = highlight; t.highlightColor = highlightColor; t.hasShadow = hasShadow
        return t
    }

    func layer(_ string: String, name: String) -> Layer {
        Layer(name: name, transform: LayerTransform(center: center, size: boxSize), content: .text(content(string)))
    }
}

/// A ready-to-use promo screenshot layout — background + device placement +
/// headline (and optional subtitle). Applied per page across a set.
struct PromoTemplate: Identifiable {
    let id: String
    let name: String
    let aspect: CanvasAspect
    let background: BackgroundStyle
    let frame: DeviceFrameKind
    let shadow: ShadowStyle
    let cornerRadius: Double
    let deviceCenter: CGPoint
    let deviceSize: CGSize
    let tiltX: Double
    let tiltY: Double
    let cleanStatusBar: StatusBarStyle?
    let headline: TextSpec
    let subtitle: TextSpec?
    let starters: [String]

    func buildPage(imageID: String, headline headlineText: String, subtitle subtitleText: String? = nil) -> EditorCanvas {
        var s = ScreenshotContent(imageID: imageID)
        s.frame = frame; s.shadow = shadow; s.cornerRadius = cornerRadius; s.cleanStatusBar = cleanStatusBar
        let screenshot = Layer(
            name: "Screenshot",
            transform: LayerTransform(center: deviceCenter, size: deviceSize, rotationX: tiltX, rotationY: tiltY),
            content: .screenshot(s))
        var layers: [Layer] = [screenshot, headline.layer(headlineText, name: "Headline")]
        if let subtitle {
            layers.append(subtitle.layer(subtitleText ?? "Add a short subtitle", name: "Subtitle"))
        }
        return EditorCanvas(aspect: aspect, background: background, layers: layers)
    }
}

enum PromoTemplates {
    private static func hex(_ s: String) -> RGBAColor { RGBAColor(hex: s) ?? .black }
    private static let as67 = CanvasAspect.promo67

    private static let starterHeadlines = [
        "Everything you need", "Beautifully simple", "Ready in seconds", "Made for you", "Get started today",
    ]

    static let all: [PromoTemplate] = [
        // Classic: dark headline over light, device below.
        PromoTemplate(id: "spotlight", name: "Spotlight", aspect: as67,
            background: .solid(hex("#F3F4F7")), frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.64), deviceSize: CGSize(width: 0.86, height: 0.66),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.12), boxSize: CGSize(width: 0.86, height: 0.14),
                               fontSize: 0.036, color: hex("#15182A")),
            subtitle: TextSpec(center: CGPoint(x: 0.5, y: 0.2), boxSize: CGSize(width: 0.8, height: 0.08),
                               fontSize: 0.019, weight: .medium, color: hex("#5B6072")),
            starters: starterHeadlines),

        // Bold white headline on a vivid gradient.
        PromoTemplate(id: "bold", name: "Bold", aspect: as67,
            background: BackgroundPresets.gradients[0].style, frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.66), deviceSize: CGSize(width: 0.84, height: 0.62),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.13), boxSize: CGSize(width: 0.9, height: 0.16),
                               fontSize: 0.044, color: .white, hasShadow: true),
            subtitle: nil, starters: starterHeadlines),

        // 3-D tilted device on mesh.
        PromoTemplate(id: "tilt", name: "Tilt", aspect: as67,
            background: BackgroundPresets.meshes[0].style, frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.63), deviceSize: CGSize(width: 0.9, height: 0.64),
            tiltX: 0.08, tiltY: 0.16, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.13), boxSize: CGSize(width: 0.9, height: 0.16),
                               fontSize: 0.04, color: .white, hasShadow: true),
            subtitle: nil, starters: starterHeadlines),

        // Gradient-filled headline on lagoon mesh.
        PromoTemplate(id: "pop", name: "Pop", aspect: as67,
            background: BackgroundPresets.meshes[2].style, frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.65), deviceSize: CGSize(width: 0.84, height: 0.62),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.12), boxSize: CGSize(width: 0.9, height: 0.16),
                               fontSize: 0.044, weight: .black, gradient: [.white, hex("#FFE29F")], hasShadow: true),
            subtitle: nil, starters: starterHeadlines),

        // Dark mode.
        PromoTemplate(id: "dark", name: "Dark", aspect: as67,
            background: .solid(hex("#0B1020")), frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.64), deviceSize: CGSize(width: 0.86, height: 0.64),
            tiltX: 0, tiltY: 0, cleanStatusBar: .light,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.12), boxSize: CGSize(width: 0.88, height: 0.14),
                               fontSize: 0.038, color: .white),
            subtitle: TextSpec(center: CGPoint(x: 0.5, y: 0.2), boxSize: CGSize(width: 0.8, height: 0.08),
                               fontSize: 0.019, weight: .medium, color: hex("#9AA0B2")),
            starters: starterHeadlines),

        // Device peeking from the bottom, big headline on top.
        PromoTemplate(id: "peek", name: "Peek", aspect: as67,
            background: BackgroundPresets.gradients[1].style, frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.82), deviceSize: CGSize(width: 0.88, height: 0.74),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.16), boxSize: CGSize(width: 0.92, height: 0.24),
                               fontSize: 0.052, weight: .black, color: .white, hasShadow: true),
            subtitle: nil, starters: starterHeadlines),

        // Minimal frameless with soft shadow.
        PromoTemplate(id: "minimal", name: "Minimal", aspect: as67,
            background: .solid(hex("#FAFAFB")), frame: .none, shadow: .medium, cornerRadius: 0.06,
            deviceCenter: CGPoint(x: 0.5, y: 0.62), deviceSize: CGSize(width: 0.78, height: 0.62),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.13), boxSize: CGSize(width: 0.84, height: 0.12),
                               fontSize: 0.032, weight: .bold, family: .rounded, color: hex("#15182A")),
            subtitle: nil, starters: starterHeadlines),

        // Marker-highlighted headline.
        PromoTemplate(id: "marker", name: "Marker", aspect: as67,
            background: .solid(hex("#FFF6E9")), frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.65), deviceSize: CGSize(width: 0.84, height: 0.62),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.13), boxSize: CGSize(width: 0.86, height: 0.14),
                               fontSize: 0.038, color: hex("#15182A"),
                               highlight: .marker, highlightColor: hex("#FFD84D")),
            subtitle: nil, starters: starterHeadlines),

        // Browser frame for web / Mac apps.
        PromoTemplate(id: "browser", name: "Browser", aspect: as67,
            background: BackgroundPresets.gradients[4].style, frame: .browserLight, shadow: .strong, cornerRadius: 0.03,
            deviceCenter: CGPoint(x: 0.5, y: 0.56), deviceSize: CGSize(width: 0.9, height: 0.5),
            tiltX: 0, tiltY: 0, cleanStatusBar: nil,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.16), boxSize: CGSize(width: 0.9, height: 0.16),
                               fontSize: 0.04, color: .white, hasShadow: true),
            subtitle: nil, starters: starterHeadlines),

        // Pattern duotone.
        PromoTemplate(id: "duotone", name: "Duotone", aspect: as67,
            background: .pattern(.dots, hex("#B9C0FF"), hex("#EEF0FF")), frame: .iphone, shadow: .strong, cornerRadius: 0.05,
            deviceCenter: CGPoint(x: 0.5, y: 0.65), deviceSize: CGSize(width: 0.84, height: 0.62),
            tiltX: 0, tiltY: 0, cleanStatusBar: .dark,
            headline: TextSpec(center: CGPoint(x: 0.5, y: 0.13), boxSize: CGSize(width: 0.86, height: 0.14),
                               fontSize: 0.038, color: hex("#3A2E8C")),
            subtitle: nil, starters: starterHeadlines),
    ]

    static func template(_ id: String) -> PromoTemplate { all.first { $0.id == id } ?? all[0] }

    /// Build a multi-page project: one page per image, cycling starter headlines.
    static func generateSet(name: String, template: PromoTemplate, imageIDs: [String], now: Date) -> Project {
        let ids = imageIDs.isEmpty ? [] : imageIDs
        let pages = ids.enumerated().map { index, id in
            template.buildPage(imageID: id, headline: template.starters[index % template.starters.count])
        }
        var project = Project(name: name, createdAt: now, modifiedAt: now, canvas: pages.first ?? template.buildPage(imageID: "", headline: template.starters[0]))
        project.pages = pages.isEmpty ? [project.canvas] : pages
        return project
    }
}
