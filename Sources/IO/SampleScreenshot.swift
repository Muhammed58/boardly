import UIKit

/// Generates a synthetic app screenshot so users (and first-run demos) can try
/// the editor without hunting for one in their library.
enum SampleScreenshot {

    static func make() -> UIImage {
        let size = CGSize(width: 1170, height: 2532)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1).setFill()
            cg.fill(bounds)

            // Gradient header.
            let headerRect = CGRect(x: 0, y: 0, width: size.width, height: 620)
            let colors = [UIColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1).cgColor,
                          UIColor(red: 0.62, green: 0.40, blue: 0.94, alpha: 1).cgColor]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.saveGState(); cg.addRect(headerRect); cg.clip()
                cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: 620), options: [])
                cg.restoreGState()
            }

            // Status bar.
            draw("9:41", at: CGPoint(x: 70, y: 60), size: 34, weight: .semibold, color: .white)
            drawRight("􀛨 􀙇 100%", maxX: size.width - 70, y: 60, size: 30, color: .white)

            // Title + subtitle.
            draw("Discover", at: CGPoint(x: 70, y: 180), size: 76, weight: .heavy, color: .white)
            draw("Trending this week", at: CGPoint(x: 72, y: 290), size: 34, weight: .regular, color: UIColor(white: 1, alpha: 0.85))

            // Search pill.
            let search = CGRect(x: 70, y: 380, width: size.width - 140, height: 96)
            UIColor(white: 1, alpha: 0.22).setFill()
            UIBezierPath(roundedRect: search, cornerRadius: 48).fill()
            draw("Search", at: CGPoint(x: 130, y: 405), size: 34, weight: .regular, color: UIColor(white: 1, alpha: 0.9))

            // Card grid.
            let cardColors = [UIColor(red: 1.0, green: 0.58, blue: 0.36, alpha: 1),
                              UIColor(red: 0.30, green: 0.78, blue: 0.62, alpha: 1),
                              UIColor(red: 0.36, green: 0.62, blue: 0.98, alpha: 1),
                              UIColor(red: 0.96, green: 0.44, blue: 0.62, alpha: 1)]
            let titles = ["Mountains", "Coastline", "City Lights", "Desert"]
            let cardW = (size.width - 70 * 2 - 40) / 2
            let cardH: CGFloat = 520
            for i in 0..<4 {
                let col = CGFloat(i % 2), row = CGFloat(i / 2)
                let x = 70 + col * (cardW + 40)
                let y = 720 + row * (cardH + 40)
                let card = CGRect(x: x, y: y, width: cardW, height: cardH)
                UIColor.white.setFill()
                let path = UIBezierPath(roundedRect: card, cornerRadius: 34)
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 12), blur: 34, color: UIColor(white: 0, alpha: 0.12).cgColor)
                path.fill()
                cg.restoreGState()
                let photo = CGRect(x: x, y: y, width: cardW, height: cardH * 0.62)
                cardColors[i].setFill()
                let clip = UIBezierPath(roundedRect: card, cornerRadius: 34)
                cg.saveGState(); clip.addClip()
                UIRectFill(photo)
                cg.restoreGState()
                draw(titles[i], at: CGPoint(x: x + 34, y: y + cardH * 0.62 + 34), size: 40, weight: .bold, color: UIColor(white: 0.1, alpha: 1))
                pill(CGRect(x: x + 34, y: y + cardH * 0.62 + 100, width: cardW - 130, height: 22), color: UIColor(white: 0.85, alpha: 1), cg: cg)
            }

            // Bottom tab bar.
            let tabRect = CGRect(x: 0, y: size.height - 200, width: size.width, height: 200)
            UIColor.white.setFill(); UIRectFill(tabRect)
            let icons = ["house.fill", "magnifyingglass", "heart", "person"]
            for (i, name) in icons.enumerated() {
                let cx = size.width * (CGFloat(i) + 0.5) / 4
                let color = i == 0 ? UIColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1) : UIColor(white: 0.7, alpha: 1)
                if let img = UIImage(systemName: name)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)) {
                    let tinted = img.withTintColor(color, renderingMode: .alwaysOriginal)
                    tinted.draw(at: CGPoint(x: cx - tinted.size.width / 2, y: size.height - 150))
                }
            }
        }
    }

    // MARK: draw helpers

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }
    private static func drawRight(_ text: String, maxX: CGFloat, y: CGFloat, size: CGFloat, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color]
        let s = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: CGPoint(x: maxX - s.width, y: y), withAttributes: attrs)
    }
    private static func pill(_ rect: CGRect, color: UIColor, cg: CGContext) {
        color.setFill(); UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
    }
}
