import CoreGraphics

/// A target output size / aspect ratio for the canvas. Presets cover the
/// social + marketing sizes people export screenshots to.
struct CanvasAspect: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var group: String
    /// Export pixel dimensions.
    var width: CGFloat
    var height: CGFloat
    /// SF Symbol shown in the picker.
    var symbol: String

    var ratio: CGFloat { height == 0 ? 1 : width / height }
    var pixelSize: CGSize { CGSize(width: width, height: height) }

    static let square      = CanvasAspect(id: "square",   name: "Square",        group: "Social", width: 1080, height: 1080, symbol: "square")
    static let portrait45  = CanvasAspect(id: "portrait", name: "Portrait 4:5",  group: "Social", width: 1080, height: 1350, symbol: "rectangle.portrait")
    static let story       = CanvasAspect(id: "story",    name: "Story 9:16",    group: "Social", width: 1080, height: 1920, symbol: "iphone")
    static let landscape   = CanvasAspect(id: "landscape",name: "Wide 16:9",     group: "Social", width: 1600, height: 900,  symbol: "rectangle")
    static let ogImage     = CanvasAspect(id: "og",       name: "Link 1.91:1",   group: "Social", width: 1200, height: 630,  symbol: "link")
    static let twitter     = CanvasAspect(id: "twitter",  name: "X Post",        group: "Social", width: 1600, height: 900,  symbol: "at")
    static let pinterest   = CanvasAspect(id: "pin",      name: "Pin 2:3",       group: "Social", width: 1000, height: 1500, symbol: "pin")

    static let appStore67  = CanvasAspect(id: "as67",     name: "iPhone 6.7\"",  group: "App Store", width: 1290, height: 2796, symbol: "iphone")
    static let appStore65  = CanvasAspect(id: "as65",     name: "iPhone 6.5\"",  group: "App Store", width: 1242, height: 2688, symbol: "iphone")
    static let appStore55  = CanvasAspect(id: "as55",     name: "iPhone 5.5\"",  group: "App Store", width: 1242, height: 2208, symbol: "iphone")
    static let appStoreiPad = CanvasAspect(id: "asipad",  name: "iPad 12.9\"",   group: "App Store", width: 2048, height: 2732, symbol: "ipad")

    static let original    = CanvasAspect(id: "original", name: "Original",      group: "Basic",  width: 1170, height: 2532, symbol: "photo")
    static let free        = CanvasAspect(id: "free",     name: "Freeform",      group: "Basic",  width: 1170, height: 2532, symbol: "crop")

    static let all: [CanvasAspect] = [
        .original, .square, .portrait45, .story, .landscape, .ogImage, .twitter, .pinterest,
        .appStore67, .appStore65, .appStore55, .appStoreiPad
    ]

    static let groups: [String] = ["Basic", "Social", "App Store"]

    /// A canvas sized to wrap `source` with `paddingFraction` breathing room,
    /// used when a screenshot is imported with the "Original" aspect.
    static func matching(source: CGSize, paddingFraction: CGFloat = 0.14) -> CanvasAspect {
        let scale: CGFloat = 1 + paddingFraction * 2
        let w = max(source.width, 1) * scale
        let h = max(source.height, 1) * scale
        return CanvasAspect(id: "original", name: "Original", group: "Basic",
                            width: w.rounded(), height: h.rounded(), symbol: "photo")
    }
}
