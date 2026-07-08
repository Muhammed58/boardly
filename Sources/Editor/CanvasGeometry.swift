import CoreGraphics
import Foundation

/// Maps between on-screen points and the canvas's normalized 0…1 space, and
/// hit-tests layers. Built fresh each layout pass from the canvas display rect.
struct CanvasGeometry {
    /// The rect on screen (in the editor's coordinate space) the canvas occupies.
    let display: CGRect

    func point(_ norm: CGPoint) -> CGPoint {
        CGPoint(x: display.minX + norm.x * display.width, y: display.minY + norm.y * display.height)
    }

    func norm(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - display.minX) / display.width, y: (p.y - display.minY) / display.height)
    }

    func normSize(_ s: CGSize) -> CGSize {
        CGSize(width: s.width / display.width, height: s.height / display.height)
    }

    /// Unrotated on-screen rect for a layer.
    func rect(for t: LayerTransform) -> CGRect {
        let c = point(t.center)
        let sz = CGSize(width: t.size.width * display.width, height: t.size.height * display.height)
        return CGRect(center: c, size: sz)
    }

    // MARK: Hit testing

    func hitTest(_ p: CGPoint, layers: [Layer]) -> Layer? {
        for layer in layers.reversed() where !layer.isHidden {
            if hits(p, layer: layer) { return layer }
        }
        return nil
    }

    private func hits(_ p: CGPoint, layer: Layer) -> Bool {
        if case .annotation(let a) = layer.content {
            switch a.kind {
            case .pen, .highlighter:
                return false // select from the Layers panel
            case .arrow, .line:
                guard a.points.count >= 2 else { return false }
                let r = rect(for: layer.transform)
                let p0 = CGPoint(x: r.minX + a.points[0].x * r.width, y: r.minY + a.points[0].y * r.height)
                let p1 = CGPoint(x: r.minX + a.points[1].x * r.width, y: r.minY + a.points[1].y * r.height)
                return distance(from: p, toSegment: p0, p1) < 22
            default:
                break
            }
        }
        return containsRotated(p, transform: layer.transform)
    }

    func containsRotated(_ p: CGPoint, transform t: LayerTransform) -> Bool {
        let c = point(t.center)
        let sz = CGSize(width: t.size.width * display.width, height: t.size.height * display.height)
        let dx = p.x - c.x, dy = p.y - c.y
        let a = -CGFloat(t.rotation)
        let lx = dx * cos(a) - dy * sin(a)
        let ly = dx * sin(a) + dy * cos(a)
        let pad: CGFloat = 6 // easier to tap thin layers
        return abs(lx) <= sz.width / 2 + pad && abs(ly) <= sz.height / 2 + pad
    }

    private func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return p.distance(to: a) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq
        t = max(0, min(1, t))
        let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return p.distance(to: proj)
    }
}
