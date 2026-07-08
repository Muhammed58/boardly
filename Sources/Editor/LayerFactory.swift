import CoreGraphics
import Foundation

/// Describes what the next canvas gesture should create (set by a tool panel,
/// consumed by the canvas).
enum PendingCreation: Equatable {
    case annotation(AnnotationKind)
    case redaction(RedactionStyle)
    case spotlight
    case text
    case callout
    case sticker(StickerKind)
    case magnifier
    case mosaicBrush

    /// Drag-defined shapes size themselves from the gesture; the rest drop at a
    /// tap with a sensible default size.
    var isDragDefined: Bool {
        switch self {
        case .annotation(let k): return k != .numberBadge
        case .redaction, .spotlight, .magnifier: return true
        case .text, .callout, .sticker, .mosaicBrush: return false
        }
    }

    /// Freehand kinds capture a live drag path.
    var isFreehand: Bool {
        switch self {
        case .annotation(let k): return k.isFreehand
        case .mosaicBrush: return true
        default: return false
        }
    }
}

/// Builds default layers for placement.
enum LayerFactory {

    /// A layer from a drag rectangle (normalized). `start`→`end` are the drag
    /// endpoints in canvas 0…1 space.
    static func make(_ pending: PendingCreation, from start: CGPoint, to end: CGPoint, color: RGBAColor) -> Layer {
        switch pending {
        case .annotation(let kind):
            return annotation(kind, from: start, to: end, color: color)
        case .redaction(let style):
            let box = box(start, end, min: 0.06)
            return Layer(name: "Redaction",
                         transform: LayerTransform(center: box.center, size: box.size),
                         content: .redaction(RedactionContent(style: style)))
        case .spotlight:
            let box = box(start, end, min: 0.12)
            return Layer(name: "Spotlight",
                         transform: LayerTransform(center: box.center, size: box.size),
                         content: .spotlight(SpotlightContent()))
        case .text:
            return text(at: start)
        case .callout:
            return callout(at: start)
        case .sticker(let kind):
            return sticker(kind, at: start)
        case .magnifier:
            let box = box(start, end, min: 0.12)
            return Layer(name: "Magnifier",
                         transform: LayerTransform(center: box.center, size: box.size),
                         content: .magnifier(MagnifierContent(source: box.center)))
        case .mosaicBrush:
            return mosaicFreehand(color: color, first: start)
        }
    }

    static func callout(at center: CGPoint, string: String = "Say something") -> Layer {
        var content = TextContent()
        content.string = string
        content.color = .black
        content.hasShadow = false
        content.bubble = .bottomLeft
        return Layer(name: "Callout",
                     transform: LayerTransform(center: clampCenter(center), size: CGSize(width: 0.5, height: 0.12)),
                     content: .text(content))
    }

    /// A full-canvas freehand mosaic (pixelate brush) the canvas appends to live.
    static func mosaicFreehand(color: RGBAColor, first: CGPoint) -> Layer {
        var content = RedactionContent(style: .pixelate, intensity: 0.02)
        content.path = [first]
        content.brushWidth = 0.06
        return Layer(name: "Mosaic",
                     transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1)),
                     content: .redaction(content))
    }

    static func text(at center: CGPoint, string: String = "Double-tap to edit") -> Layer {
        var content = TextContent()
        content.string = string
        return Layer(name: "Text",
                     transform: LayerTransform(center: clampCenter(center), size: CGSize(width: 0.7, height: 0.14)),
                     content: .text(content))
    }

    /// An additional screenshot layer (collage), sized so its box hugs the
    /// image aspect within `widthFrac` of the canvas width.
    static func screenshot(imageID: String, imageAspect: CGFloat, canvasRatio: CGFloat,
                           widthFrac: CGFloat = 0.5, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> Layer {
        let boxH = widthFrac * canvasRatio / max(imageAspect, 0.01)
        var content = ScreenshotContent(imageID: imageID)
        content.shadow = .soft
        return Layer(name: "Screenshot",
                     transform: LayerTransform(center: center, size: CGSize(width: widthFrac, height: boxH)),
                     content: .screenshot(content))
    }

    static func sticker(_ kind: StickerKind, at center: CGPoint) -> Layer {
        Layer(name: "Sticker",
              transform: LayerTransform(center: clampCenter(center), size: CGSize(width: 0.22, height: 0.22)),
              content: .sticker(StickerContent(kind: kind)))
    }

    /// A full-canvas freehand annotation the canvas appends points to live.
    static func freehand(_ kind: AnnotationKind, color: RGBAColor, first: CGPoint) -> Layer {
        Layer(name: kind.displayName,
              transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1)),
              content: .annotation(AnnotationContent(kind: kind, color: color, points: [first])))
    }

    // MARK: Annotations

    private static func annotation(_ kind: AnnotationKind, from start: CGPoint, to end: CGPoint, color: RGBAColor) -> Layer {
        switch kind {
        case .arrow, .line:
            // Full-canvas box, absolute normalized endpoints (edited via handles).
            return Layer(name: kind.displayName,
                         transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1)),
                         content: .annotation(AnnotationContent(kind: kind, color: color, points: [start, end])))
        case .numberBadge:
            return Layer(name: "Step",
                         transform: LayerTransform(center: clampCenter(start), size: CGSize(width: 0.12, height: 0.12)),
                         content: .annotation(AnnotationContent(kind: kind, color: color, points: [], number: 1)))
        default: // rectangle, ellipse
            let box = box(start, end, min: 0.05)
            return Layer(name: kind.displayName,
                         transform: LayerTransform(center: box.center, size: box.size),
                         content: .annotation(AnnotationContent(kind: kind, color: color)))
        }
    }

    // MARK: Helpers

    private static func box(_ a: CGPoint, _ b: CGPoint, min minSize: CGFloat) -> (center: CGPoint, size: CGSize) {
        let w = Swift.max(abs(b.x - a.x), minSize)
        let h = Swift.max(abs(b.y - a.y), minSize)
        let cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2
        return (CGPoint(x: cx, y: cy), CGSize(width: w, height: h))
    }

    private static func clampCenter(_ p: CGPoint) -> CGPoint {
        CGPoint(x: Swift.min(Swift.max(p.x, 0.05), 0.95), y: Swift.min(Swift.max(p.y, 0.05), 0.95))
    }
}
