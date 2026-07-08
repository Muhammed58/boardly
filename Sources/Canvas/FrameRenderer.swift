import UIKit

/// Draws device / browser / window chrome around a screenshot, entirely with
/// Core Graphics (no bundled PNG frames — crisp at any resolution).
///
/// Returns a `UIImage` of the framed screenshot at its natural aspect, with
/// transparency outside the rounded silhouette. The compositor then applies
/// shadow / 3-D tilt / rotation and draws it aspect-fit inside the layer box.
enum FrameRenderer {

    struct Result {
        let image: UIImage
        /// width / height of the framed unit.
        let aspect: CGFloat
    }

    // Traffic-light colors.
    private static let tlRed = UIColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1)
    private static let tlYellow = UIColor(red: 0.99, green: 0.74, blue: 0.18, alpha: 1)
    private static let tlGreen = UIColor(red: 0.16, green: 0.78, blue: 0.25, alpha: 1)

    /// Render the framed screenshot. `contentCornerFraction` rounds the raw
    /// screenshot for the frameless / window cases.
    static func render(frame: DeviceFrameKind,
                       screenshot: UIImage,
                       contentCornerFraction: CGFloat,
                       browserURL: String,
                       width W: CGFloat) -> Result {
        let imgAspect = max(screenshot.size.width, 1) / max(screenshot.size.height, 1)

        switch frame {
        case .none:
            return rounded(screenshot, cornerFraction: contentCornerFraction, width: W, aspect: imgAspect)
        case .browserLight:
            return browser(screenshot, dark: false, url: browserURL, width: W, imgAspect: imgAspect)
        case .browserDark:
            return browser(screenshot, dark: true, url: browserURL, width: W, imgAspect: imgAspect)
        case .macWindow:
            return window(screenshot, dark: false, barFraction: 0.075, url: nil, width: W, imgAspect: imgAspect)
        case .windowLight:
            return window(screenshot, dark: false, barFraction: 0.052, url: nil, width: W, imgAspect: imgAspect)
        case .windowDark:
            return window(screenshot, dark: true, barFraction: 0.052, url: nil, width: W, imgAspect: imgAspect)
        case .iphone:
            return phone(screenshot, width: W, island: true)
        case .ipad:
            return phone(screenshot, width: W, island: false)
        case .android:
            return androidPhone(screenshot, width: W)
        case .watch:
            return watch(screenshot, width: W)
        case .studioDisplay:
            return studioDisplay(screenshot, width: W)
        }
    }

    // MARK: Android

    private static func androidPhone(_ shot: UIImage, width W: CGFloat) -> Result {
        let screenAspect: CGFloat = 9.0 / 20.0
        let bezel = W * 0.026
        let screenW = W - bezel * 2
        let screenH = screenW / screenAspect
        let H = (screenH + bezel * 2).rounded()
        let size = CGSize(width: W, height: H)
        let outerRadius = W * 0.10
        let screenRadius = outerRadius - bezel * 0.6
        let img = image(size) { ctx in
            let cg = ctx.cgContext
            let outer = CGRect(origin: .zero, size: size)
            UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1).setFill()
            UIBezierPath(roundedRect: outer, cornerRadius: outerRadius).fill()
            let screenRect = CGRect(x: bezel, y: bezel, width: screenW, height: screenH)
            cg.saveGState()
            UIBezierPath(roundedRect: screenRect, cornerRadius: screenRadius).addClip()
            shot.draw(in: aspectFill(shot.size, into: screenRect))
            cg.restoreGState()
            // Punch-hole camera.
            let d = bezel * 0.9
            UIColor.black.setFill()
            UIBezierPath(ovalIn: CGRect(x: W / 2 - d / 2, y: bezel + screenH * 0.018, width: d, height: d)).fill()
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Apple Watch

    private static func watch(_ shot: UIImage, width W: CGFloat) -> Result {
        let H = W / 0.82
        let size = CGSize(width: W, height: H)
        let bezel = W * 0.12
        let img = image(size) { ctx in
            let cg = ctx.cgContext
            // Case.
            UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: W * 0.30).fill()
            // Digital crown.
            UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: W - W * 0.05, y: H * 0.42, width: W * 0.06, height: H * 0.16), cornerRadius: W * 0.03).fill()
            // Screen.
            let screenRect = CGRect(x: bezel, y: bezel, width: W - bezel * 2, height: H - bezel * 2)
            cg.saveGState()
            UIBezierPath(roundedRect: screenRect, cornerRadius: W * 0.20).addClip()
            UIColor.black.setFill(); UIRectFill(screenRect)
            shot.draw(in: aspectFill(shot.size, into: screenRect))
            cg.restoreGState()
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Studio Display (monitor on a stand)

    private static func studioDisplay(_ shot: UIImage, width W: CGFloat) -> Result {
        let bezel = W * 0.018
        let screenAspect: CGFloat = 16.0 / 10.0
        let screenW = W - bezel * 2
        let screenH = screenW / screenAspect
        let panelH = screenH + bezel * 2
        let neckH = W * 0.10
        let baseH = W * 0.02
        let H = (panelH + neckH + baseH).rounded()
        let size = CGSize(width: W, height: H)
        let img = image(size) { ctx in
            let cg = ctx.cgContext
            // Stand neck + base.
            UIColor(white: 0.72, alpha: 1).setFill()
            let neck = UIBezierPath()
            neck.move(to: CGPoint(x: W * 0.42, y: panelH))
            neck.addLine(to: CGPoint(x: W * 0.58, y: panelH))
            neck.addLine(to: CGPoint(x: W * 0.62, y: panelH + neckH))
            neck.addLine(to: CGPoint(x: W * 0.38, y: panelH + neckH))
            neck.close(); neck.fill()
            UIColor(white: 0.78, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: W * 0.28, y: H - baseH, width: W * 0.44, height: baseH), cornerRadius: baseH / 2).fill()
            // Panel.
            UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: W, height: panelH), cornerRadius: W * 0.02).fill()
            let screenRect = CGRect(x: bezel, y: bezel, width: screenW, height: screenH)
            cg.saveGState()
            UIBezierPath(roundedRect: screenRect, cornerRadius: W * 0.006).addClip()
            shot.draw(in: aspectFill(shot.size, into: screenRect))
            cg.restoreGState()
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Frameless (rounded corners only)

    private static func rounded(_ shot: UIImage, cornerFraction: CGFloat, width W: CGFloat, aspect: CGFloat) -> Result {
        let H = (W / aspect).rounded()
        let size = CGSize(width: W, height: H)
        let radius = min(W, H) * cornerFraction
        let img = image(size) { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            shot.draw(in: rect)
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Browser

    private static func browser(_ shot: UIImage, dark: Bool, url: String, width W: CGFloat, imgAspect: CGFloat) -> Result {
        let bar = (W * 0.085).rounded()
        let contentH = W / imgAspect
        let H = (bar + contentH).rounded()
        let size = CGSize(width: W, height: H)
        let radius = W * 0.028
        let chrome = dark ? UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1) : UIColor(red: 0.95, green: 0.95, blue: 0.965, alpha: 1)
        let pill = dark ? UIColor(white: 1, alpha: 0.10) : UIColor(white: 1, alpha: 1)
        let ink = dark ? UIColor(white: 1, alpha: 0.55) : UIColor(white: 0.35, alpha: 1)

        let img = image(size) { ctx in
            let outer = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: outer, cornerRadius: radius).addClip()
            chrome.setFill(); UIRectFill(outer)

            // Traffic lights.
            let r = bar * 0.16
            let cy = bar / 2
            let colors = [tlRed, tlYellow, tlGreen]
            for (i, c) in colors.enumerated() {
                c.setFill()
                let x = bar * 0.55 + CGFloat(i) * r * 3.1
                UIBezierPath(ovalIn: CGRect(x: x, y: cy - r, width: r * 2, height: r * 2)).fill()
            }

            // URL pill.
            let pillH = bar * 0.52
            let pillRect = CGRect(x: W * 0.30, y: cy - pillH / 2, width: W * 0.40, height: pillH)
            pill.setFill()
            UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2).fill()
            let font = UIFont.systemFont(ofSize: pillH * 0.52, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let text = url as NSString
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: pillRect.midX - ts.width / 2, y: pillRect.midY - ts.height / 2), withAttributes: attrs)

            // Screenshot.
            shot.draw(in: CGRect(x: 0, y: bar, width: W, height: contentH))
            ctx.cgContext.setStrokeColor(UIColor(white: dark ? 1 : 0, alpha: 0.06).cgColor)
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Generic window (mac / minimal)

    private static func window(_ shot: UIImage, dark: Bool, barFraction: CGFloat, url: String?, width W: CGFloat, imgAspect: CGFloat) -> Result {
        let bar = (W * barFraction).rounded()
        let contentH = W / imgAspect
        let H = (bar + contentH).rounded()
        let size = CGSize(width: W, height: H)
        let radius = W * 0.026
        let chrome = dark ? UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1) : UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1)

        let img = image(size) { _ in
            let outer = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: outer, cornerRadius: radius).addClip()
            chrome.setFill(); UIRectFill(outer)
            let r = bar * 0.17
            let cy = bar / 2
            for (i, c) in [tlRed, tlYellow, tlGreen].enumerated() {
                c.setFill()
                let x = bar * 0.5 + CGFloat(i) * r * 3.1
                UIBezierPath(ovalIn: CGRect(x: x, y: cy - r, width: r * 2, height: r * 2)).fill()
            }
            shot.draw(in: CGRect(x: 0, y: bar, width: W, height: contentH))
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Phone / tablet bezel

    private static func phone(_ shot: UIImage, width W: CGFloat, island: Bool) -> Result {
        // Bezel + screen. Screen aspect follows a modern phone (19.5:9) or 4:3 tablet.
        let screenAspect: CGFloat = island ? (9.0 / 19.5) : (3.0 / 4.0) // w/h
        let bezel = W * (island ? 0.032 : 0.028)
        let screenW = W - bezel * 2
        let screenH = screenW / screenAspect
        let H = (screenH + bezel * 2).rounded()
        let size = CGSize(width: W, height: H)
        let outerRadius = W * (island ? 0.14 : 0.055)
        let screenRadius = outerRadius - bezel * 0.7

        let img = image(size) { ctx in
            let cg = ctx.cgContext
            // Bezel body.
            let outer = CGRect(origin: .zero, size: size)
            let bezelPath = UIBezierPath(roundedRect: outer, cornerRadius: outerRadius)
            UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1).setFill()
            bezelPath.fill()
            // Subtle rim highlight.
            cg.setStrokeColor(UIColor(white: 1, alpha: 0.10).cgColor)
            cg.setLineWidth(W * 0.004)
            bezelPath.stroke()

            // Screen.
            let screenRect = CGRect(x: bezel, y: bezel, width: screenW, height: screenH)
            let screenClip = UIBezierPath(roundedRect: screenRect, cornerRadius: screenRadius)
            cg.saveGState()
            screenClip.addClip()
            // Aspect-fill screenshot into the screen.
            let fill = aspectFill(shot.size, into: screenRect)
            shot.draw(in: fill)
            cg.restoreGState()

            // Dynamic Island.
            if island {
                let iw = screenW * 0.30, ih = bezel * 1.7
                let ir = CGRect(x: (W - iw) / 2, y: bezel + screenH * 0.012, width: iw, height: ih)
                UIColor.black.setFill()
                UIBezierPath(roundedRect: ir, cornerRadius: ih / 2).fill()
            }
        }
        return Result(image: img, aspect: W / H)
    }

    // MARK: Helpers

    private static func image(_ size: CGSize, _ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: draw)
    }

    private static func aspectFill(_ src: CGSize, into rect: CGRect) -> CGRect {
        let scale = max(rect.width / src.width, rect.height / src.height)
        let w = src.width * scale, h = src.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
