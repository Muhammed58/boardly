import UIKit
import Photos

enum ExportFormat: String, CaseIterable, Identifiable {
    case png, jpeg, pdf
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var ext: String { self == .jpeg ? "jpg" : rawValue }
    var supportsTransparency: Bool { self == .png }
}

/// Renders and exports a canvas at a chosen size/format, and writes to Photos,
/// share sheet, clipboard, or Instagram-carousel slices.
@MainActor
enum Exporter {

    static func render(_ canvas: EditorCanvas, scale: CGFloat, transparent: Bool) -> UIImage {
        let base = canvas.pixelSize
        let px = CGSize(width: base.width * scale, height: base.height * scale)
        return CanvasRenderer.shared.render(canvas, pixelSize: px, quality: .export, transparent: transparent)
    }

    static func data(_ image: UIImage, format: ExportFormat, quality: CGFloat) -> Data? {
        switch format {
        case .png: return image.pngData()
        case .jpeg: return image.jpegData(compressionQuality: quality)
        case .pdf:
            let bounds = CGRect(origin: .zero, size: image.size)
            return UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in ctx.beginPage(); image.draw(in: bounds) }
        }
    }

    /// Write to a temp file (for sharing with the right extension).
    static func writeTemp(_ data: Data, ext: String, name: String = "Boardly") -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).\(ext)")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    static func copyToClipboard(_ image: UIImage) { UIPasteboard.general.image = image }

    static func saveToPhotos(_ image: UIImage, pngData: Data?) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                if let pngData, let url = writeTemp(pngData, ext: "png") {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, fileURL: url, options: nil)
                } else {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }, completionHandler: { ok, _ in continuation.resume(returning: ok) })
        }
    }

    /// Slice a wide image into `count` equal square-ish panels for an IG carousel.
    static func carouselSlices(_ image: UIImage, count: Int) -> [UIImage] {
        guard count > 1, let cg = image.cgImage else { return [image] }
        let w = cg.width / count
        return (0..<count).compactMap { i in
            cg.cropping(to: CGRect(x: i * w, y: 0, width: w, height: cg.height)).map { UIImage(cgImage: $0) }
        }
    }
}
