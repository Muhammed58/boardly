import UIKit

/// Draws a text layer with the same code the export uses (WYSIWYG). Supports
/// gradient fill, marker/underline/box highlight, speech-bubble background, and
/// curved (arc) text. All sizes are fractions of the canvas so they scale.
enum TextLayerRenderer {

    static func draw(_ t: TextContent, in rect: CGRect, canvasSize: CGSize, context cg: CGContext) {
        let fontSize = max(t.fontSize * canvasSize.height, 2)
        let font = t.family.uiFont(size: fontSize, weight: t.weight)

        if let curve = t.curve, abs(curve) > 0.001 {
            drawCurved(t, font: font, in: rect, curve: curve, cg: cg)
            return
        }

        let para = NSMutableParagraphStyle()
        para.alignment = t.align.nsAlignment
        para.lineSpacing = fontSize * max(0, t.lineSpacing - 1)
        para.lineBreakMode = .byWordWrapping

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: t.color.uiColor, .paragraphStyle: para,
        ]
        if t.hasStroke {
            attrs[.strokeColor] = t.strokeColor.uiColor
            attrs[.strokeWidth] = -abs(t.strokeWidth) * 100
        }

        let string = t.string.isEmpty ? " " : t.string
        let attributed = NSAttributedString(string: string, attributes: attrs)

        let measured = attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).size
        let block = CGRect(center: rect.center,
                           size: CGSize(width: min(ceil(measured.width) + 2, rect.width), height: ceil(measured.height)))

        // Speech bubble / pill background.
        if let tail = t.bubble {
            drawBubble(around: block, tail: tail, fill: (t.background ?? .white), fontSize: fontSize, cg: cg)
        } else if let bg = t.background {
            let pad = fontSize * t.backgroundPadding
            let pill = block.insetBy(dx: -pad, dy: -pad * 0.7)
            bg.uiColor.setFill()
            UIBezierPath(roundedRect: pill, cornerRadius: min(pill.height / 2, fontSize * t.backgroundCornerRadius + pad)).fill()
        }

        // Highlight behind glyphs.
        if let hl = t.highlight {
            drawHighlight(hl, color: (t.highlightColor ?? RGBAColor(hex: "#FFE24D")!), block: block, fontSize: fontSize, cg: cg)
        }

        // Glyphs: gradient or solid.
        cg.saveGState()
        if t.hasShadow {
            cg.setShadow(offset: CGSize(width: 0, height: fontSize * 0.04), blur: fontSize * 0.16,
                         color: UIColor(white: 0, alpha: 0.35).cgColor)
        }
        if let gradient = t.gradient, gradient.count >= 2 {
            drawGradientText(attributed, in: block, colors: gradient, cg: cg)
        } else {
            attributed.draw(with: block, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
        cg.restoreGState()
    }

    // MARK: Gradient fill

    private static func drawGradientText(_ attributed: NSAttributedString, in block: CGRect, colors: [RGBAColor], cg: CGContext) {
        guard block.width > 1, block.height > 1 else { return }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1; format.opaque = false
        let bounds = CGRect(origin: .zero, size: block.size)
        let cgColors = colors.map(\.cgColor) as CFArray
        let locs = (0..<colors.count).map { CGFloat($0) / CGFloat(colors.count - 1) }
        // Draw the gradient, then keep only the text-shaped region (destination-in).
        let masked = UIGraphicsImageRenderer(size: block.size, format: format).image { ctx in
            let g = ctx.cgContext
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locs) {
                g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: block.height), options: [])
            }
            g.setBlendMode(.destinationIn)
            attributed.draw(with: bounds, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
        masked.draw(in: block)
    }

    // MARK: Highlight

    private static func drawHighlight(_ hl: TextHighlight, color: RGBAColor, block: CGRect, fontSize: CGFloat, cg: CGContext) {
        switch hl {
        case .marker:
            color.opacity(0.55).uiColor.setFill()
            let r = block.insetBy(dx: -fontSize * 0.12, dy: fontSize * 0.06)
            UIBezierPath(roundedRect: r, cornerRadius: fontSize * 0.12).fill()
        case .underline:
            color.uiColor.setFill()
            UIBezierPath(rect: CGRect(x: block.minX, y: block.maxY - fontSize * 0.06, width: block.width, height: fontSize * 0.14)).fill()
        case .box:
            color.uiColor.setStroke()
            let path = UIBezierPath(roundedRect: block.insetBy(dx: -fontSize * 0.18, dy: -fontSize * 0.12), cornerRadius: fontSize * 0.18)
            path.lineWidth = fontSize * 0.08
            path.stroke()
        }
    }

    // MARK: Bubble

    private static func drawBubble(around block: CGRect, tail: BubbleTail, fill: RGBAColor, fontSize: CGFloat, cg: CGContext) {
        let pad = fontSize * 0.55
        let body = block.insetBy(dx: -pad, dy: -pad * 0.8)
        let radius = fontSize * 0.5
        fill.uiColor.setFill()
        let path = UIBezierPath(roundedRect: body, cornerRadius: radius)
        // Tail.
        if tail != .none {
            let s = fontSize * 0.7
            let t = UIBezierPath()
            switch tail {
            case .bottomLeft:  t.move(to: CGPoint(x: body.minX + s, y: body.maxY)); t.addLine(to: CGPoint(x: body.minX + s * 0.4, y: body.maxY + s)); t.addLine(to: CGPoint(x: body.minX + s * 2, y: body.maxY))
            case .bottomRight: t.move(to: CGPoint(x: body.maxX - s, y: body.maxY)); t.addLine(to: CGPoint(x: body.maxX - s * 0.4, y: body.maxY + s)); t.addLine(to: CGPoint(x: body.maxX - s * 2, y: body.maxY))
            case .topLeft:     t.move(to: CGPoint(x: body.minX + s, y: body.minY)); t.addLine(to: CGPoint(x: body.minX + s * 0.4, y: body.minY - s)); t.addLine(to: CGPoint(x: body.minX + s * 2, y: body.minY))
            case .topRight:    t.move(to: CGPoint(x: body.maxX - s, y: body.minY)); t.addLine(to: CGPoint(x: body.maxX - s * 0.4, y: body.minY - s)); t.addLine(to: CGPoint(x: body.maxX - s * 2, y: body.minY))
            case .none: break
            }
            t.close(); path.append(t)
        }
        path.fill()
    }

    // MARK: Curved text

    private static func drawCurved(_ t: TextContent, font: UIFont, in rect: CGRect, curve: Double, cg: CGContext) {
        let chars = Array(t.string.isEmpty ? " " : t.string)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: t.color.uiColor]
        let widths = chars.map { (String($0) as NSString).size(withAttributes: attrs).width }
        let total = max(widths.reduce(0, +), 1)
        let angleSpan = CGFloat(curve) * .pi * 0.9
        let radius = total / max(abs(angleSpan), 0.001)
        let sign: CGFloat = curve >= 0 ? 1 : -1
        let center = CGPoint(x: rect.midX, y: rect.midY + radius * sign)

        cg.saveGState()
        var consumed: CGFloat = 0
        for (i, ch) in chars.enumerated() {
            let w = widths[i]
            let midArc = (consumed + w / 2) / total       // 0…1
            let theta = angleSpan * (midArc - 0.5)
            let point = CGPoint(x: center.x + radius * sin(theta) * 1, y: center.y - radius * cos(theta) * sign)
            cg.saveGState()
            cg.translateBy(x: point.x, y: point.y)
            cg.rotate(by: theta)
            let s = String(ch) as NSString
            s.draw(at: CGPoint(x: -w / 2, y: -font.lineHeight / 2), withAttributes: attrs)
            cg.restoreGState()
            consumed += w
        }
        cg.restoreGState()
    }
}
