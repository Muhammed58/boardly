import Vision
import UIKit

/// One-tap privacy: finds likely-sensitive regions (emails, phone numbers,
/// long tokens/card numbers, and faces) so they can be auto-redacted. Returns
/// normalized rects with a top-left origin (matching the canvas coordinate
/// convention), lightly inflated for full coverage.
enum SensitiveContentDetector {

    static func detect(in image: UIImage) async -> [CGRect] {
        guard let cg = image.normalizedUp().cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var rects: [CGRect] = []
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)

                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = false

                let faceRequest = VNDetectFaceRectanglesRequest()

                try? handler.perform([textRequest, faceRequest])

                for observation in textRequest.results ?? [] {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    if isSensitive(candidate.string) {
                        rects.append(inflate(convert(observation.boundingBox)))
                    }
                }
                for face in faceRequest.results ?? [] {
                    rects.append(inflate(convert(face.boundingBox), by: 0.06))
                }
                continuation.resume(returning: rects)
            }
        }
    }

    // Vision boundingBoxes are normalized with a bottom-left origin; flip to top-left.
    private static func convert(_ b: CGRect) -> CGRect {
        CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
    }

    private static func inflate(_ r: CGRect, by f: CGFloat = 0.02) -> CGRect {
        r.insetBy(dx: -r.width * f - 0.004, dy: -r.height * f - 0.004)
    }

    private static func isSensitive(_ text: String) -> Bool {
        let s = text.trimmingCharacters(in: .whitespaces)
        if s.contains("@") && s.contains(".") { return true }               // email
        let digits = s.filter(\.isNumber).count
        if digits >= 6 { return true }                                       // phone / card / code
        if s.count >= 14 && s.contains(where: \.isNumber) && s.contains(where: \.isLetter) { return true } // token/key
        return false
    }
}
