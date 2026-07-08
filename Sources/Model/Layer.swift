import CoreGraphics
import Foundation

// MARK: - Layer

/// One element on the canvas. Every layer shares the same `transform` so the
/// editor's move/resize/rotate gizmo works uniformly; each `content` type
/// decides how to draw itself inside the layer's unit box.
struct Layer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var transform: LayerTransform
    var opacity: Double = 1
    var isHidden: Bool = false
    var content: LayerContent

    var symbol: String { content.symbol }
    var kindLabel: String { content.kindLabel }
    var isScreenshot: Bool { if case .screenshot = content { return true }; return false }
}

// MARK: - Layer content

enum LayerContent: Codable, Equatable {
    case screenshot(ScreenshotContent)
    case text(TextContent)
    case annotation(AnnotationContent)
    case redaction(RedactionContent)
    case spotlight(SpotlightContent)
    case sticker(StickerContent)
    case magnifier(MagnifierContent)

    var symbol: String {
        switch self {
        case .screenshot: return "photo"
        case .text(let t): return t.bubble == nil ? "textformat" : "bubble.left.fill"
        case .annotation(let a): return a.kind.symbol
        case .redaction(let r): return r.style.symbol
        case .spotlight: return "flashlight.on.fill"
        case .sticker: return "face.smiling"
        case .magnifier: return "plus.magnifyingglass"
        }
    }

    var kindLabel: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .text(let t): return t.bubble == nil ? "Text" : "Callout"
        case .annotation(let a): return a.kind.displayName
        case .redaction: return "Redaction"
        case .spotlight: return "Spotlight"
        case .sticker: return "Sticker"
        case .magnifier: return "Magnifier"
        }
    }
}

// MARK: - Screenshot

struct ScreenshotContent: Codable, Equatable {
    var imageID: String
    /// Corner radius as a fraction of the layer's min side.
    var cornerRadius: Double = 0.045
    var frame: DeviceFrameKind = .none
    var shadow: ShadowStyle = .medium
    /// Address shown in a browser frame's URL bar.
    var browserURL: String = "boardly.app"

    // Additive, optional (nil = legacy default) so old projects still decode.
    /// Silhouette the screenshot is clipped to (nil = rounded rectangle).
    var clipShape: ScreenshotClip? = nil
    /// Glossy glass highlight over the frame.
    var glass: Bool? = nil
    /// Mirror reflection beneath the screenshot.
    var reflection: Bool? = nil
    /// Overlay a clean status bar (9:41, full signal, 100%).
    var cleanStatusBar: StatusBarStyle? = nil
}

// MARK: - Text

struct TextContent: Codable, Equatable {
    var string: String = "Double-tap to edit"
    var family: FontFamily = .system
    var weight: FontWeight = .bold
    /// Font size as a fraction of canvas height.
    var fontSize: Double = 0.05
    var color: RGBAColor = .white
    var align: TextAlign = .center
    var lineSpacing: Double = 1.05
    var hasStroke: Bool = false
    var strokeColor: RGBAColor = .black
    /// Stroke width as a fraction of font size.
    var strokeWidth: Double = 0.08
    var hasShadow: Bool = true
    /// Optional pill background behind the text.
    var background: RGBAColor? = nil
    var backgroundPadding: Double = 0.5
    var backgroundCornerRadius: Double = 0.4

    // Additive, optional (nil = legacy behavior).
    /// Gradient fill for the glyphs (overrides `color` when set).
    var gradient: [RGBAColor]? = nil
    /// Marker / underline / box highlight behind the text.
    var highlight: TextHighlight? = nil
    var highlightColor: RGBAColor? = nil
    /// Arc amount for curved text (-1…1, 0 = straight).
    var curve: Double? = nil
    /// Speech-bubble styling (tail direction). When set the text renders in a bubble.
    var bubble: BubbleTail? = nil
}

// MARK: - Annotation

enum AnnotationKind: String, Codable, CaseIterable, Identifiable {
    case arrow, line, rectangle, ellipse, highlighter, pen, numberBadge
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .rectangle: return "Box"
        case .ellipse: return "Circle"
        case .highlighter: return "Highlight"
        case .pen: return "Pen"
        case .numberBadge: return "Step"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .highlighter: return "highlighter"
        case .pen: return "scribble.variable"
        case .numberBadge: return "1.circle.fill"
        }
    }

    /// Freehand kinds capture a live drag path; the rest are drawn from the box.
    var isFreehand: Bool { self == .pen || self == .highlighter }
}

struct AnnotationContent: Codable, Equatable {
    var kind: AnnotationKind
    var color: RGBAColor
    /// Stroke width as a fraction of the canvas min side.
    var strokeWidth: Double = 0.008
    var filled: Bool = false
    /// Local 0…1 points inside the layer box. Arrow/line use [start, end];
    /// pen/highlighter use the whole captured path; box/ellipse ignore it.
    var points: [CGPoint] = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0)]
    var number: Int = 1
}

// MARK: - Redaction

struct RedactionContent: Codable, Equatable {
    var style: RedactionStyle = .blur
    /// Blur radius / pixel size as a fraction of canvas min side.
    var intensity: Double = 0.02
    var cornerRadius: Double = 0.02

    // Freehand "mosaic brush": when set, the effect follows a stroked path
    // (in local 0…1) instead of filling the box.
    var path: [CGPoint]? = nil
    var brushWidth: Double? = nil
}

// MARK: - Magnifier (loupe)

struct MagnifierContent: Codable, Equatable {
    /// Point on the canvas (0…1) the loupe samples and zooms.
    var source: CGPoint = CGPoint(x: 0.5, y: 0.4)
    var zoom: Double = 2.2
    var shape: SpotlightShape = .ellipse
    var borderColor: RGBAColor = .white
    var borderWidth: Double = 0.006
    var cornerRadius: Double = 0.03
}

// MARK: - Spotlight

enum SpotlightShape: String, Codable, CaseIterable { case rectangle, ellipse }

struct SpotlightContent: Codable, Equatable {
    var dimOpacity: Double = 0.55
    var shape: SpotlightShape = .rectangle
    /// Edge softness as a fraction of canvas min side.
    var feather: Double = 0.02
    var cornerRadius: Double = 0.03
}

// MARK: - Sticker

enum StickerKind: Codable, Equatable {
    case emoji(String)
    case image(id: String)
}

struct StickerContent: Codable, Equatable {
    var kind: StickerKind
}
