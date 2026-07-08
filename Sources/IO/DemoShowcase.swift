import UIKit

/// Builds a richly-composed demo project (browser frame, mesh background,
/// headline, arrow) used by the BOARDLY_DEMO verification hook to exercise the
/// full render pipeline at once.
enum DemoShowcase {

    static func project(imageID: String, imageSize: CGSize) -> Project {
        var canvas = EditorCanvas.beautified(imageID: imageID, imageSize: imageSize)
        canvas.aspect = .portrait45
        canvas.background = BackgroundPresets.meshes[0].style // Aurora
        canvas.vignette = 0.3
        canvas.watermark = WatermarkSpec()

        if let id = canvas.primaryScreenshot?.id, var layer = canvas[id],
           case .screenshot(var s) = layer.content {
            s.frame = .browserLight
            s.shadow = .strong
            s.browserURL = "boardly.app"
            s.cleanStatusBar = .dark
            layer.content = .screenshot(s)
            layer.transform.center = CGPoint(x: 0.5, y: 0.54)
            layer.transform.size = CGSize(width: 0.82, height: 0.66)
            canvas[id] = layer
        }

        // Magnifier loupe over the lower-left card.
        canvas.layers.append(Layer(
            name: "Magnifier",
            transform: LayerTransform(center: CGPoint(x: 0.3, y: 0.74), size: CGSize(width: 0.26, height: 0.26)),
            content: .magnifier(MagnifierContent(source: CGPoint(x: 0.36, y: 0.66), zoom: 2.4))))

        var headline = TextContent()
        headline.string = "Ship it 🚀"
        headline.weight = .heavy
        headline.fontSize = 0.062
        headline.color = .white
        headline.hasShadow = true
        canvas.layers.append(Layer(
            name: "Headline",
            transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.12), size: CGSize(width: 0.8, height: 0.1)),
            content: .text(headline)))

        var arrow = AnnotationContent(kind: .arrow, color: RGBAColor(hex: "#FF3B30") ?? .black)
        arrow.strokeWidth = 0.011
        arrow.points = [CGPoint(x: 0.24, y: 0.86), CGPoint(x: 0.44, y: 0.66)]
        canvas.layers.append(Layer(
            name: "Arrow",
            transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1)),
            content: .annotation(arrow)))

        return Project(name: "Showcase", createdAt: Date(), modifiedAt: Date(), canvas: canvas)
    }
}
