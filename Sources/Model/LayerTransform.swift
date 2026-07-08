import CoreGraphics

/// Placement of a layer inside the canvas, in normalized 0…1 space.
///
/// `center` and `size` are fractions of the canvas dimensions, so a project
/// renders identically at any output resolution — the same value drives the
/// on-screen preview and the full-resolution export (single render path).
struct LayerTransform: Codable, Equatable {
    /// Center of the layer, 0…1 in canvas space.
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Size of the layer as a fraction of the canvas (width, height).
    var size: CGSize = CGSize(width: 0.6, height: 0.4)
    /// In-plane (z) rotation, radians.
    var rotation: Double = 0
    /// 3-D pitch (about the x-axis), radians — used for perspective tilt.
    var rotationX: Double = 0
    /// 3-D yaw (about the y-axis), radians.
    var rotationY: Double = 0

    /// The layer's bounding rect in the given pixel-space canvas size.
    func rect(in canvas: CGSize) -> CGRect {
        let s = CGSize(width: size.width * canvas.width, height: size.height * canvas.height)
        let c = CGPoint(x: center.x * canvas.width, y: center.y * canvas.height)
        return CGRect(center: c, size: s)
    }

    var hasPerspective: Bool { abs(rotationX) > 0.0001 || abs(rotationY) > 0.0001 }
    var isRotated: Bool { abs(rotation) > 0.0001 }
}
