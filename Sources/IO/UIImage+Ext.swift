import UIKit
import CoreImage

extension UIImage {
    /// Average color of a region (default whole image), via `CIAreaAverage`.
    func averageColor(in rect: CGRect? = nil) -> RGBAColor? {
        guard let cg = cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let r = rect ?? ci.extent
        let extent = CIVector(x: r.minX, y: r.minY, z: r.width, w: r.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ci, kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return RGBAColor(red: Double(bitmap[0]) / 255, green: Double(bitmap[1]) / 255, blue: Double(bitmap[2]) / 255)
    }

    /// A palette sampled from horizontal bands — used for palette-matched backgrounds.
    func dominantColors(_ count: Int = 3) -> [RGBAColor] {
        guard let cg = cgImage else { return [] }
        let ci = CIImage(cgImage: cg)
        let h = ci.extent.height, w = ci.extent.width
        return (0..<count).compactMap { i in
            averageColor(in: CGRect(x: 0, y: h * CGFloat(i) / CGFloat(count), width: w, height: h / CGFloat(count)))
        }
    }
}

extension UIImage {
    /// Bake in orientation so downstream Core Graphics drawing is upright.
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    func flipped(horizontal: Bool) -> UIImage {
        renderer(size).image { ctx in
            let cg = ctx.cgContext
            if horizontal { cg.translateBy(x: size.width, y: 0); cg.scaleBy(x: -1, y: 1) }
            else { cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: 1, y: -1) }
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func rotated90(clockwise: Bool) -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        return renderer(newSize).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            cg.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    /// Rotate by a small angle and over-scale so no empty corners remain.
    func straightened(degrees: CGFloat) -> UIImage {
        guard abs(degrees) > 0.05 else { return self }
        let a = abs(degrees * .pi / 180)
        let ratio = max(size.width, size.height) / min(size.width, size.height)
        let scale = cos(a) + ratio * sin(a)
        return renderer(size).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: degrees * .pi / 180)
            cg.scaleBy(x: scale, y: scale)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    func cropped(normalizedRect r: CGRect) -> UIImage {
        guard let cg = cgImage else { return self }
        let rect = CGRect(x: r.minX * CGFloat(cg.width), y: r.minY * CGFloat(cg.height),
                          width: r.width * CGFloat(cg.width), height: r.height * CGFloat(cg.height)).integral
        guard rect.width > 1, rect.height > 1, let cropped = cg.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped)
    }

    /// Sample the color at a normalized (0…1) point — used by the eyedropper.
    func pixelColor(atNormalized p: CGPoint) -> RGBAColor? {
        guard let cg = cgImage else { return nil }
        let x = Int(min(max(p.x, 0), 0.999) * CGFloat(cg.width))
        let y = Int(min(max(p.y, 0), 0.999) * CGFloat(cg.height))
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return RGBAColor(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
    }

    /// Downscaled copy whose longest side is at most `maxDimension` (for thumbnails).
    func resizedToFit(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let s = maxDimension / longest
        let target = CGSize(width: (size.width * s).rounded(), height: (size.height * s).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
