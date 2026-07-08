import UIKit

/// Overlays a clean, marketing-perfect status bar (9:41, full signal, Wi-Fi,
/// 100% battery) onto the top band of a phone screenshot, covering whatever
/// messy real status bar was there. The band is filled with the screenshot's
/// own top-edge color so it blends in.
enum StatusBarRenderer {

    static func apply(to image: UIImage, style: StatusBarStyle) -> UIImage {
        let size = image.size
        let bandH = max(size.height * 0.045, 40)
        let band = CGRect(x: 0, y: 0, width: size.width, height: bandH)
        let bg = averageColor(of: image, in: band) ?? (style == .light ? UIColor(white: 0.1, alpha: 1) : .white)
        let tint = style.tint.uiColor

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            image.draw(at: .zero)
            bg.setFill(); UIRectFill(band)
            draw(in: band, tint: tint)
        }
    }

    private static func draw(in band: CGRect, tint: UIColor) {
        let h = band.height
        let sideInset = band.width * 0.09
        let cy = band.midY + h * 0.06

        // Time (left).
        let font = UIFont.systemFont(ofSize: h * 0.42, weight: .semibold)
        let time = "9:41" as NSString
        let ts = time.size(withAttributes: [.font: font, .foregroundColor: tint])
        time.draw(at: CGPoint(x: sideInset, y: cy - ts.height / 2), withAttributes: [.font: font, .foregroundColor: tint])

        // Right cluster: signal, wifi, battery.
        let iconH = h * 0.36
        var x = band.width - sideInset
        for name in ["battery.100", "wifi", "cellularbars"] {
            guard let sym = UIImage(systemName: name)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: iconH, weight: .semibold))
                .withTintColor(tint, renderingMode: .alwaysOriginal) else { continue }
            let w = sym.size.width * (iconH / max(sym.size.height, 1))
            x -= w
            sym.draw(in: CGRect(x: x, y: cy - iconH / 2, width: w, height: iconH))
            x -= band.width * 0.02
        }
    }

    private static func averageColor(of image: UIImage, in rect: CGRect) -> UIColor? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let extent = CIVector(x: rect.minX, y: ci.extent.height - rect.maxY, z: rect.width, w: rect.height)
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: extent])
        guard let output = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }
}
