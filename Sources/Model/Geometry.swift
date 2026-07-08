import CoreGraphics
import Foundation

// Small geometry helpers used by the renderer and the editor gizmos.
// All model geometry is expressed in a normalized 0…1 space relative to the
// canvas, then scaled to pixels by the renderer / to points by the editor.

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }

    func scaled(to size: CGSize) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }

    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }

    func clamped(to range: ClosedRange<CGFloat> = 0...1) -> CGPoint {
        CGPoint(x: min(max(x, range.lowerBound), range.upperBound),
                y: min(max(y, range.lowerBound), range.upperBound))
    }
}

extension CGSize {
    static func * (s: CGSize, f: CGFloat) -> CGSize { CGSize(width: s.width * f, height: s.height * f) }
    var aspect: CGFloat { height == 0 ? 1 : width / height }
    var minSide: CGFloat { min(width, height) }
    var maxSide: CGFloat { max(width, height) }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2,
                  width: size.width, height: size.height)
    }

    /// Largest rect of `aspect` (w/h) that fits inside `self`, centered.
    func fitting(aspect: CGFloat) -> CGRect {
        guard aspect > 0 else { return self }
        var w = width, h = width / aspect
        if h > height { h = height; w = height * aspect }
        return CGRect(center: center, size: CGSize(width: w, height: h))
    }
}
