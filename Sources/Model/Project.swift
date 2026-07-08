import CoreGraphics
import Foundation

/// A saved document. The `canvas` holds everything needed to re-render at any
/// resolution; images are stored separately by id in the ImageStore.
struct Project: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    /// The active page (also page 0 / the thumbnail source for backward compat).
    var canvas: EditorCanvas
    /// All pages (App Store sets). Optional so pre-multipage projects still decode;
    /// nil means a single page equal to `canvas`.
    var pages: [EditorCanvas]? = nil

    init(id: UUID = UUID(), name: String, createdAt: Date, modifiedAt: Date, canvas: EditorCanvas) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.canvas = canvas
    }
}

/// The renderable document body: an output size, a backdrop, and ordered layers
/// (index 0 = bottom).
struct EditorCanvas: Codable, Equatable {
    var aspect: CanvasAspect
    var background: BackgroundStyle
    var layers: [Layer]

    // Additive, optional (nil = off) so old projects still decode.
    var vignette: Double? = nil
    var grain: Double? = nil
    var watermark: WatermarkSpec? = nil

    var pixelSize: CGSize { aspect.pixelSize }

    /// The primary (first) screenshot layer, if any.
    var primaryScreenshot: Layer? { layers.first { $0.isScreenshot } }

    func index(of id: UUID) -> Int? { layers.firstIndex { $0.id == id } }

    subscript(_ id: UUID) -> Layer? {
        get { layers.first { $0.id == id } }
        set {
            guard let newValue, let i = index(of: id) else { return }
            layers[i] = newValue
        }
    }
}

// MARK: - Factory

extension EditorCanvas {
    /// A fresh canvas wrapping a just-imported screenshot: centered, padded,
    /// rounded corners + soft shadow on a pleasant gradient — the default look.
    static func beautified(imageID: String, imageSize: CGSize) -> EditorCanvas {
        let aspect = CanvasAspect.matching(source: imageSize)
        // Fit the screenshot into the padded canvas.
        let fit: CGFloat = 1 / (1 + 0.14 * 2)
        let screenshot = Layer(
            name: "Screenshot",
            transform: LayerTransform(
                center: CGPoint(x: 0.5, y: 0.5),
                size: CGSize(width: fit, height: fit)
            ),
            content: .screenshot(ScreenshotContent(imageID: imageID))
        )
        return EditorCanvas(
            aspect: aspect,
            background: BackgroundPresets.defaultBackground.style,
            layers: [screenshot]
        )
    }
}

extension Project {
    static func new(imageID: String, imageSize: CGSize, now: Date) -> Project {
        Project(name: "Screenshot",
                createdAt: now,
                modifiedAt: now,
                canvas: .beautified(imageID: imageID, imageSize: imageSize))
    }
}
