import UIKit

/// Draws annotation layers (arrows, boxes, freehand, step badges). Geometry is
/// in the layer's local 0…1 box, mapped to the given `rect`.
enum AnnotationRenderer {

    static func draw(_ a: AnnotationContent, in rect: CGRect, canvasSize: CGSize, context cg: CGContext) {
        let lineWidth = max(a.strokeWidth * canvasSize.minSide, 1)
        let color = a.color.uiColor

        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
        }

        cg.saveGState()
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.setLineWidth(lineWidth)
        color.setStroke()
        color.setFill()

        switch a.kind {
        case .line:
            let pts = a.points
            guard pts.count >= 2 else { break }
            strokePath([map(pts[0]), map(pts[1])], cg: cg)

        case .arrow:
            let pts = a.points
            guard pts.count >= 2 else { break }
            let start = map(pts[0]), end = map(pts[1])
            strokePath([start, end], cg: cg)
            drawArrowhead(from: start, to: end, lineWidth: lineWidth, cg: cg)

        case .rectangle:
            let r = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = UIBezierPath(roundedRect: r, cornerRadius: lineWidth * 0.8)
            if a.filled { color.withAlphaComponent(0.28).setFill(); path.fill(); color.setStroke() }
            path.lineWidth = lineWidth
            path.stroke()

        case .ellipse:
            let r = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = UIBezierPath(ovalIn: r)
            if a.filled { color.withAlphaComponent(0.28).setFill(); path.fill(); color.setStroke() }
            path.lineWidth = lineWidth
            path.stroke()

        case .pen:
            strokePath(a.points.map(map), cg: cg)

        case .highlighter:
            cg.setBlendMode(.multiply)
            cg.setLineWidth(lineWidth * 3.2)
            color.withAlphaComponent(0.42).setStroke()
            strokePath(a.points.map(map), cg: cg)

        case .numberBadge:
            let d = rect.size.minSide
            let circle = CGRect(center: rect.center, size: CGSize(width: d, height: d))
            color.setFill()
            UIBezierPath(ovalIn: circle).fill()
            let text = "\(a.number)" as NSString
            let fontSize = d * 0.56
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let ink: UIColor = a.color.luminance > 0.6 ? .black : .white
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: circle.midX - ts.width / 2, y: circle.midY - ts.height / 2), withAttributes: attrs)
        }

        cg.restoreGState()
    }

    private static func strokePath(_ points: [CGPoint], cg: CGContext) {
        guard points.count >= 2 else { return }
        let path = UIBezierPath()
        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
        } else {
            // Smooth freehand with quadratic segments through midpoints.
            for i in 1..<points.count - 1 {
                let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2,
                                  y: (points[i].y + points[i + 1].y) / 2)
                path.addQuadCurve(to: mid, controlPoint: points[i])
            }
            path.addLine(to: points[points.count - 1])
        }
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func drawArrowhead(from: CGPoint, to: CGPoint, lineWidth: CGFloat, cg: CGContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let len = lineWidth * 3.8
        let spread = CGFloat.pi / 7
        let p1 = CGPoint(x: to.x - len * cos(angle - spread), y: to.y - len * sin(angle - spread))
        let p2 = CGPoint(x: to.x - len * cos(angle + spread), y: to.y - len * sin(angle + spread))
        let head = UIBezierPath()
        head.move(to: to); head.addLine(to: p1)
        head.addLine(to: p2); head.close()
        head.fill()
    }
}
