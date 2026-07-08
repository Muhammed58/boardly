import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies a 3-D pitch/yaw tilt to an image using a real perspective projection
/// (`CIPerspectiveTransform`). Used for the screenshot "tilt" effect. Falls back
/// to the original image if anything degenerate happens.
enum PerspectiveWarp {

    static func apply(_ image: UIImage, rotationX: Double, rotationY: Double, context: CIContext) -> UIImage? {
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        let w = ci.extent.width, h = ci.extent.height
        guard w > 1, h > 1 else { return image }

        let phi = clampAngle(rotationX)   // pitch (about x)
        let theta = clampAngle(rotationY) // yaw (about y)

        // Corners centered at origin, CI coords (y up): tl, tr, bl, br.
        let hw = w / 2, hh = h / 2
        let model: [SIMD3<Double>] = [
            [-hw,  hh, 0], [hw,  hh, 0],
            [-hw, -hh, 0], [hw, -hh, 0],
        ]
        let cam = Double(max(w, h)) * 2.2
        let projected = model.map { project(rotate($0, pitch: phi, yaw: theta), cam: cam) }

        // Normalize to positive space.
        let minX = projected.map(\.x).min() ?? 0
        let minY = projected.map(\.y).min() ?? 0
        let pts = projected.map { CGPoint(x: $0.x - minX, y: $0.y - minY) }

        let filter = CIFilter.perspectiveTransform()
        filter.inputImage = ci
        filter.topLeft = pts[0]
        filter.topRight = pts[1]
        filter.bottomLeft = pts[2]
        filter.bottomRight = pts[3]
        guard let out = filter.outputImage, !out.extent.isInfinite, !out.extent.isEmpty,
              let result = context.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: result)
    }

    private static func clampAngle(_ radians: Double) -> Double {
        let limit = Double.pi / 3 // ±60°
        return min(max(radians, -limit), limit)
    }

    private static func rotate(_ p: SIMD3<Double>, pitch: Double, yaw: Double) -> SIMD3<Double> {
        // Yaw about y.
        let cy = cos(yaw), sy = sin(yaw)
        let x1 = p.x * cy + p.z * sy
        let z1 = -p.x * sy + p.z * cy
        let y1 = p.y
        // Pitch about x.
        let cx = cos(pitch), sx = sin(pitch)
        let y2 = y1 * cx - z1 * sx
        let z2 = y1 * sx + z1 * cx
        return [x1, y2, z2]
    }

    private static func project(_ p: SIMD3<Double>, cam: Double) -> CGPoint {
        let denom = max(cam - p.z, 1)
        let scale = cam / denom
        return CGPoint(x: p.x * scale, y: p.y * scale)
    }
}
