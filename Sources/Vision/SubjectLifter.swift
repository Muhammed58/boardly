import Vision
import CoreImage
import UIKit

/// Lifts the foreground subject out of an image (transparent background) using
/// the iOS-17 foreground-instance mask — the modern successor to the person
/// segmentation the original app used, now working on any subject.
enum SubjectLifter {

    static func lift(_ image: UIImage) async -> UIImage? {
        guard let cg = image.normalizedUp().cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
                do {
                    try handler.perform([request])
                    guard let result = request.results?.first else {
                        continuation.resume(returning: nil); return
                    }
                    let buffer = try result.generateMaskedImage(
                        ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
                    let ci = CIImage(cvPixelBuffer: buffer)
                    let context = CIContext()
                    guard let out = context.createCGImage(ci, from: ci.extent) else {
                        continuation.resume(returning: nil); return
                    }
                    continuation.resume(returning: UIImage(cgImage: out))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
