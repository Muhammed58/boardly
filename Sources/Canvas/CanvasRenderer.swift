import UIKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum RenderQuality { case preview, export }

/// The single render path. Composites an `EditorCanvas` to a bitmap at any
/// resolution — the on-screen preview and the exported image run this exact
/// code, so what you see is what you get.
///
/// Layers draw in z-order into a running accumulator. Redaction (blur/pixelate)
/// is the only pass that needs to read the pixels beneath it, so it flushes the
/// accumulator, applies a Core Image effect to the region, and continues.
@MainActor
final class CanvasRenderer {
    static let shared = CanvasRenderer()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var backgroundCache: (key: Int, image: UIImage)?
    /// When true the background is skipped and contexts keep their alpha
    /// channel (for transparent PNG export).
    private var transparentMode = false

    // MARK: Entry point

    func render(_ canvas: EditorCanvas, pixelSize: CGSize, quality: RenderQuality, transparent: Bool = false) -> UIImage {
        transparentMode = transparent
        defer { transparentMode = false }
        let size = CGSize(width: max(pixelSize.width.rounded(), 2), height: max(pixelSize.height.rounded(), 2))

        var accumulator = transparent
            ? opaqueImage(size) { _ in }
            : backgroundImage(canvas.background, size: size, canvas: canvas)
        var pending: [Layer] = []

        func flush() {
            guard !pending.isEmpty else { return }
            accumulator = composite(base: accumulator, layers: pending, size: size)
            pending.removeAll()
        }

        for layer in canvas.layers where !layer.isHidden {
            switch layer.content {
            case .redaction(let r) where r.style != .solid:
                flush()
                accumulator = applyRedaction(r, transform: layer.transform, opacity: layer.opacity, base: accumulator, size: size)
            case .magnifier(let m):
                flush()
                accumulator = applyMagnifier(m, transform: layer.transform, base: accumulator, size: size)
            default:
                pending.append(layer)
            }
        }
        flush()
        accumulator = applyCanvasEffects(canvas, base: accumulator, size: size)
        return accumulator
    }

    // MARK: Background

    private func backgroundImage(_ style: BackgroundStyle, size: CGSize, canvas: EditorCanvas) -> UIImage {
        let key = backgroundKey(style, size: size, canvas: canvas)
        if let cached = backgroundCache, cached.key == key { return cached.image }
        let image = renderBackground(style, size: size, canvas: canvas)
        backgroundCache = (key, image)
        return image
    }

    private func renderBackground(_ style: BackgroundStyle, size: CGSize, canvas: EditorCanvas) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        switch style {
        case .solid(let c):
            return opaqueImage(size) { _ in c.uiColor.setFill(); UIRectFill(rect) }

        case .linearGradient(let colors, let angle):
            return opaqueImage(size) { ctx in drawLinearGradient(colors, angle: angle, rect: rect, cg: ctx.cgContext) }

        case .radialGradient(let colors):
            return opaqueImage(size) { ctx in drawRadialGradient(colors, rect: rect, cg: ctx.cgContext) }

        case .mesh(let spec):
            let renderer = ImageRenderer(content: MeshBackground(spec: spec).frame(width: size.width, height: size.height))
            renderer.scale = 1
            renderer.isOpaque = true
            return renderer.uiImage ?? opaqueImage(size) { _ in UIColor.systemPurple.setFill(); UIRectFill(rect) }

        case .image(let id, let fill):
            let img = ImageStore.shared.image(for: id)
            return opaqueImage(size) { _ in
                UIColor.black.setFill(); UIRectFill(rect)
                guard let img else { return }
                img.draw(in: fill ? aspectFill(img.size, into: rect) : rect.fitting(aspect: img.size.aspect))
            }

        case .blurredScreenshot(let radius):
            let shot = primaryScreenshotImage(canvas)
            return opaqueImage(size) { _ in
                UIColor.systemGray.setFill(); UIRectFill(rect)
                guard let shot, let blurred = gaussian(shot, sigma: size.minSide * radius) else { return }
                blurred.draw(in: aspectFill(blurred.size, into: rect))
            }

        case .pattern(let pattern, let fg, let bg):
            return opaqueImage(size) { ctx in
                bg.uiColor.setFill(); UIRectFill(rect)
                drawPattern(pattern, fg: fg.uiColor, size: size, cg: ctx.cgContext)
            }
        }
    }

    private func drawPattern(_ pattern: BackgroundPattern, fg: UIColor, size: CGSize, cg: CGContext) {
        let step = size.minSide / 22
        cg.saveGState()
        switch pattern {
        case .dots:
            fg.withAlphaComponent(0.5).setFill()
            let r = step * 0.14
            var y = step
            while y < size.height { var x = step; while x < size.width {
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)); x += step }; y += step }
        case .grid, .graph:
            fg.withAlphaComponent(pattern == .graph ? 0.22 : 0.35).setStroke()
            cg.setLineWidth(max(size.minSide * 0.0015, 0.5))
            let s = pattern == .graph ? step * 0.5 : step
            var x = s; while x < size.width { cg.move(to: CGPoint(x: x, y: 0)); cg.addLine(to: CGPoint(x: x, y: size.height)); x += s }
            var y = s; while y < size.height { cg.move(to: CGPoint(x: 0, y: y)); cg.addLine(to: CGPoint(x: size.width, y: y)); y += s }
            cg.strokePath()
        case .diagonal:
            fg.withAlphaComponent(0.3).setStroke()
            cg.setLineWidth(step * 0.18)
            var x = -size.height; while x < size.width { cg.move(to: CGPoint(x: x, y: 0)); cg.addLine(to: CGPoint(x: x + size.height, y: size.height)); x += step * 1.6 }
            cg.strokePath()
        case .noise:
            drawGrain(strength: 0.6, size: size, cg: cg)
        }
        cg.restoreGState()
    }

    private func backgroundKey(_ style: BackgroundStyle, size: CGSize, canvas: EditorCanvas) -> Int {
        var hasher = Hasher()
        hasher.combine(Int(size.width)); hasher.combine(Int(size.height))
        switch style {
        case .solid(let c): hasher.combine(0); hasher.combine(c)
        case .linearGradient(let c, let a): hasher.combine(1); hasher.combine(c); hasher.combine(a)
        case .radialGradient(let c): hasher.combine(2); hasher.combine(c)
        case .mesh(let m): hasher.combine(3); hasher.combine(m.colors); hasher.combine(m.rows); hasher.combine(m.cols)
        case .image(let id, let f): hasher.combine(4); hasher.combine(id); hasher.combine(f)
        case .blurredScreenshot(let r): hasher.combine(5); hasher.combine(r); hasher.combine(canvas.primaryScreenshot?.id)
        case .pattern(let p, let fg, let bg): hasher.combine(6); hasher.combine(p); hasher.combine(fg); hasher.combine(bg)
        }
        return hasher.finalize()
    }

    // MARK: Compositing a batch of draw-layers

    private func composite(base: UIImage, layers: [Layer], size: CGSize) -> UIImage {
        opaqueImage(size) { ctx in
            let cg = ctx.cgContext
            base.draw(in: CGRect(origin: .zero, size: size))
            for layer in layers { drawLayer(layer, in: cg, canvasSize: size) }
        }
    }

    private func drawLayer(_ layer: Layer, in cg: CGContext, canvasSize: CGSize) {
        let rect = layer.transform.rect(in: canvasSize)
        cg.saveGState()
        cg.setAlpha(CGFloat(layer.opacity))
        switch layer.content {
        case .screenshot(let s):
            drawScreenshot(s, transform: layer.transform, in: cg, canvasSize: canvasSize)
        case .text(let t):
            withRotation(layer.transform, rect: rect, cg: cg) {
                TextLayerRenderer.draw(t, in: rect, canvasSize: canvasSize, context: cg)
            }
        case .annotation(let a):
            withRotation(layer.transform, rect: rect, cg: cg) {
                AnnotationRenderer.draw(a, in: rect, canvasSize: canvasSize, context: cg)
            }
        case .redaction(let r): // only .solid reaches here
            withRotation(layer.transform, rect: rect, cg: cg) {
                UIColor.black.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: r.cornerRadius * canvasSize.minSide).fill()
            }
        case .spotlight(let s):
            drawSpotlight(s, rect: rect, canvasSize: canvasSize, cg: cg)
        case .sticker(let st):
            withRotation(layer.transform, rect: rect, cg: cg) {
                drawSticker(st, rect: rect, cg: cg)
            }
        case .magnifier:
            break // handled as a readback pass in render()
        }
        cg.restoreGState()
    }

    // MARK: Screenshot

    private func drawScreenshot(_ s: ScreenshotContent, transform: LayerTransform, in cg: CGContext, canvasSize: CGSize) {
        guard var shot = ImageStore.shared.image(for: s.imageID) else { return }
        if let statusBar = s.cleanStatusBar { shot = StatusBarRenderer.apply(to: shot, style: statusBar) }
        let layerRect = transform.rect(in: canvasSize)
        let targetW = max(layerRect.width, 16)
        let framed = FrameRenderer.render(frame: s.frame, screenshot: shot,
                                          contentCornerFraction: s.cornerRadius,
                                          browserURL: s.browserURL, width: targetW)

        var content = framed.image
        var aspect = framed.aspect
        if transform.hasPerspective, let warped = PerspectiveWarp.apply(content, rotationX: transform.rotationX, rotationY: transform.rotationY, context: ciContext) {
            content = warped
            aspect = warped.size.aspect
        }

        let fit = CGRect(origin: .zero, size: layerRect.size).fitting(aspect: aspect)
        let drawRect = CGRect(center: layerRect.center, size: fit.size)

        cg.saveGState()
        if transform.isRotated {
            cg.translateBy(x: drawRect.midX, y: drawRect.midY)
            cg.rotate(by: CGFloat(transform.rotation))
            cg.translateBy(x: -drawRect.midX, y: -drawRect.midY)
        }
        if s.reflection == true { drawReflection(content, under: drawRect, cg: cg) }
        if s.shadow.isVisible {
            let sh = s.shadow
            cg.setShadow(offset: CGSize(width: sh.offset.width * canvasSize.minSide, height: sh.offset.height * canvasSize.minSide),
                         blur: sh.radius * canvasSize.minSide,
                         color: sh.color.opacity(sh.opacity).cgColor)
        }
        if s.frame == .none, let clip = s.clipShape, clip != .roundedRect {
            cg.saveGState()
            let path = clip == .circle
                ? UIBezierPath(ovalIn: drawRect)
                : UIBezierPath(roundedRect: drawRect, cornerRadius: drawRect.size.minSide * 0.44)
            path.addClip()
            content.draw(in: drawRect)
            cg.restoreGState()
        } else {
            content.draw(in: drawRect)
        }
        if s.glass == true { drawGlass(over: drawRect, cg: cg) }
        cg.restoreGState()
    }

    private func drawGlass(over rect: CGRect, cg: CGContext) {
        cg.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.size.minSide * 0.06).addClip()
        let colors = [UIColor(white: 1, alpha: 0.35).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.midY), options: [])
        }
        cg.restoreGState()
    }

    private func drawReflection(_ content: UIImage, under rect: CGRect, cg: CGContext) {
        let reflH = rect.height * 0.45
        let gap = rect.height * 0.015
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.opaque = false
        let refl = UIGraphicsImageRenderer(size: rect.size, format: format).image { ctx in
            let g = ctx.cgContext
            g.saveGState()
            g.translateBy(x: 0, y: rect.height); g.scaleBy(x: 1, y: -1)
            content.draw(in: CGRect(origin: .zero, size: rect.size))
            g.restoreGState()
            g.setBlendMode(.destinationIn)
            let colors = [UIColor(white: 0, alpha: 0.28).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: reflH), options: [])
            }
        }
        refl.draw(in: CGRect(x: rect.minX, y: rect.maxY + gap, width: rect.width, height: rect.height))
    }

    // MARK: Spotlight

    private func drawSpotlight(_ s: SpotlightContent, rect: CGRect, canvasSize: CGSize, cg: CGContext) {
        let full = UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize))
        let hole = s.shape == .ellipse
            ? UIBezierPath(ovalIn: rect)
            : UIBezierPath(roundedRect: rect, cornerRadius: s.cornerRadius * canvasSize.minSide)
        full.append(hole)
        full.usesEvenOddFillRule = true
        UIColor(white: 0, alpha: s.dimOpacity).setFill()
        full.fill()
    }

    // MARK: Sticker

    private func drawSticker(_ st: StickerContent, rect: CGRect, cg: CGContext) {
        switch st.kind {
        case .emoji(let emoji):
            let font = UIFont.systemFont(ofSize: rect.height * 0.86)
            let text = emoji as NSString
            let size = text.size(withAttributes: [.font: font])
            text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                      withAttributes: [.font: font])
        case .image(let id):
            guard let img = ImageStore.shared.image(for: id) else { return }
            img.draw(in: CGRect(origin: .zero, size: rect.size).fitting(aspect: img.size.aspect).offsetBy(dx: rect.minX, dy: rect.minY))
        }
    }

    // MARK: Redaction

    private func applyRedaction(_ r: RedactionContent, transform: LayerTransform, opacity: Double, base: UIImage, size: CGSize) -> UIImage {
        guard let baseCG = base.cgImage else { return base }
        let ci = CIImage(cgImage: baseCG)
        let minSide = size.minSide
        let source = ci.clampedToExtent()
        let full = CGRect(origin: .zero, size: size)

        let effectCI: CIImage?
        switch r.style {
        case .blur:
            effectCI = source.applyingGaussianBlur(sigma: Double(max(minSide * r.intensity, 1)))
        case .pixelate:
            let f = CIFilter.pixellate()
            f.inputImage = source
            f.scale = Float(max(minSide * r.intensity, 2))
            f.center = CGPoint(x: size.width / 2, y: size.height / 2)
            effectCI = f.outputImage
        case .solid:
            effectCI = nil
        }
        guard let effectCI, let effectCG = ciContext.createCGImage(effectCI.cropped(to: full), from: full) else { return base }
        let effectImage = UIImage(cgImage: effectCG)

        return opaqueImage(size) { ctx in
            let cg = ctx.cgContext
            base.draw(in: full)
            cg.saveGState()
            cg.setAlpha(CGFloat(opacity))
            let rect = transform.rect(in: size)
            if let path = r.path, !path.isEmpty {
                // Freehand mosaic brush.
                let bw = max((r.brushWidth ?? 0.05) * minSide, 4)
                let pts = path.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
                let line = CGMutablePath()
                if pts.count == 1 {
                    line.addEllipse(in: CGRect(center: pts[0], size: CGSize(width: bw, height: bw)))
                    cg.addPath(line)
                } else {
                    line.move(to: pts[0]); for p in pts.dropFirst() { line.addLine(to: p) }
                    cg.addPath(line.copy(strokingWithWidth: bw, lineCap: .round, lineJoin: .round, miterLimit: 1))
                }
                cg.clip()
            } else {
                UIBezierPath(roundedRect: rect, cornerRadius: r.cornerRadius * minSide).addClip()
            }
            effectImage.draw(in: full)
            cg.restoreGState()
        }
    }

    // MARK: Magnifier loupe

    private func applyMagnifier(_ m: MagnifierContent, transform: LayerTransform, base: UIImage, size: CGSize) -> UIImage {
        let rect = transform.rect(in: size)
        let source = CGPoint(x: m.source.x * size.width, y: m.source.y * size.height)
        let zoom = CGFloat(max(m.zoom, 1.05))
        let srcW = rect.width / zoom, srcH = rect.height / zoom
        let srcRect = CGRect(x: source.x - srcW / 2, y: source.y - srcH / 2, width: srcW, height: srcH)

        return opaqueImage(size) { ctx in
            let cg = ctx.cgContext
            base.draw(in: CGRect(origin: .zero, size: size))
            let clip = m.shape == .ellipse
                ? UIBezierPath(ovalIn: rect)
                : UIBezierPath(roundedRect: rect, cornerRadius: m.cornerRadius * size.minSide)
            cg.saveGState()
            clip.addClip()
            let scale = rect.width / max(srcW, 1)
            let originX = rect.minX - srcRect.minX * scale
            let originY = rect.minY - srcRect.minY * scale
            base.draw(in: CGRect(x: originX, y: originY, width: size.width * scale, height: size.height * scale))
            cg.restoreGState()
            m.borderColor.uiColor.setStroke()
            clip.lineWidth = max(m.borderWidth * size.minSide, 1)
            clip.stroke()
        }
    }

    // MARK: Canvas-wide effects (vignette / grain / watermark)

    private func applyCanvasEffects(_ canvas: EditorCanvas, base: UIImage, size: CGSize) -> UIImage {
        let vignette = canvas.vignette ?? 0
        let grain = canvas.grain ?? 0
        let watermark = canvas.watermark
        guard vignette > 0.001 || grain > 0.001 || watermark != nil else { return base }
        return opaqueImage(size) { ctx in
            let cg = ctx.cgContext
            base.draw(in: CGRect(origin: .zero, size: size))
            if vignette > 0.001 { drawVignette(strength: vignette, size: size, cg: cg) }
            if grain > 0.001 { drawGrain(strength: grain, size: size, cg: cg) }
            if let watermark { drawWatermark(watermark, size: size, cg: cg) }
        }
    }

    private func drawVignette(strength: Double, size: CGSize, cg: CGContext) {
        let colors = [UIColor.clear.cgColor, UIColor(white: 0, alpha: CGFloat(min(strength, 1)) * 0.9).cgColor] as CFArray
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1]) else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        cg.drawRadialGradient(grad, startCenter: center, startRadius: size.minSide * 0.2,
                              endCenter: center, endRadius: size.maxSide * 0.72, options: [.drawsAfterEndLocation])
    }

    private func drawGrain(strength: Double, size: CGSize, cg: CGContext) {
        let noise = CIFilter.randomGenerator().outputImage?
            .cropped(to: CGRect(origin: .zero, size: size))
        guard let noise else { return }
        let controls = CIFilter.colorControls()
        controls.inputImage = noise
        controls.saturation = 0
        controls.brightness = 0
        controls.contrast = 1
        guard let gray = controls.outputImage,
              let cgImage = ciContext.createCGImage(gray, from: CGRect(origin: .zero, size: size)) else { return }
        cg.saveGState()
        cg.setBlendMode(.overlay)
        cg.setAlpha(CGFloat(min(strength, 1)) * 0.5)
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        cg.restoreGState()
    }

    private func drawWatermark(_ w: WatermarkSpec, size: CGSize, cg: CGContext) {
        let margin = size.minSide * 0.03
        let targetW = size.width * w.scale
        cg.saveGState()
        cg.setAlpha(CGFloat(w.opacity))
        if let id = w.imageID, let logo = ImageStore.shared.image(for: id) {
            let h = targetW / max(logo.size.aspect, 0.01)
            logo.draw(in: place(CGSize(width: targetW, height: h), corner: w.corner, size: size, margin: margin))
        } else {
            let fontSize = targetW * 0.24
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: w.color.uiColor]
            let text = w.text as NSString
            let ts = text.size(withAttributes: attrs)
            let origin = place(ts, corner: w.corner, size: size, margin: margin).origin
            text.draw(at: origin, withAttributes: attrs)
        }
        cg.restoreGState()
    }

    private func place(_ item: CGSize, corner: WatermarkSpec.Corner, size: CGSize, margin: CGFloat) -> CGRect {
        let x: CGFloat, y: CGFloat
        switch corner {
        case .bottomRight: x = size.width - item.width - margin; y = size.height - item.height - margin
        case .bottomLeft:  x = margin; y = size.height - item.height - margin
        case .topRight:    x = size.width - item.width - margin; y = margin
        case .topLeft:     x = margin; y = margin
        case .center:      x = (size.width - item.width) / 2; y = (size.height - item.height) / 2
        }
        return CGRect(x: x, y: y, width: item.width, height: item.height)
    }

    // MARK: Gradients

    private func drawLinearGradient(_ colors: [RGBAColor], angle: Double, rect: CGRect, cg: CGContext) {
        guard let gradient = cgGradient(colors) else { return }
        let a = angle * .pi / 180
        let dx = cos(a), dy = sin(a)
        let start = CGPoint(x: rect.midX - CGFloat(dx) * rect.width / 2, y: rect.midY - CGFloat(dy) * rect.height / 2)
        let end = CGPoint(x: rect.midX + CGFloat(dx) * rect.width / 2, y: rect.midY + CGFloat(dy) * rect.height / 2)
        cg.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func drawRadialGradient(_ colors: [RGBAColor], rect: CGRect, cg: CGContext) {
        guard let gradient = cgGradient(colors) else { return }
        let center = rect.center
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                              endCenter: center, endRadius: rect.size.maxSide * 0.72,
                              options: [.drawsAfterEndLocation])
    }

    private func cgGradient(_ colors: [RGBAColor]) -> CGGradient? {
        let cgColors = colors.map(\.cgColor) as CFArray
        let locations: [CGFloat] = colors.count <= 1
            ? [0]
            : (0..<colors.count).map { CGFloat($0) / CGFloat(colors.count - 1) }
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locations)
    }

    // MARK: Utilities

    private func primaryScreenshotImage(_ canvas: EditorCanvas) -> UIImage? {
        guard case .screenshot(let s)? = canvas.primaryScreenshot?.content else { return nil }
        return ImageStore.shared.image(for: s.imageID)
    }

    private func gaussian(_ image: UIImage, sigma: CGFloat) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg).clampedToExtent().applyingGaussianBlur(sigma: Double(sigma))
        guard let out = ciContext.createCGImage(ci, from: CIImage(cgImage: cg).extent) else { return nil }
        return UIImage(cgImage: out)
    }

    private func withRotation(_ transform: LayerTransform, rect: CGRect, cg: CGContext, _ draw: () -> Void) {
        guard transform.isRotated else { draw(); return }
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY)
        cg.rotate(by: CGFloat(transform.rotation))
        cg.translateBy(x: -rect.midX, y: -rect.midY)
        draw()
        cg.restoreGState()
    }

    private func aspectFill(_ src: CGSize, into rect: CGRect) -> CGRect {
        let scale = max(rect.width / max(src.width, 1), rect.height / max(src.height, 1))
        let w = src.width * scale, h = src.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }

    private func opaqueImage(_ size: CGSize, _ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = !transparentMode
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: draw)
    }
}
