import SwiftUI

/// SwiftUI selection overlay for the selected layer. Draws only handles/outline
/// (never content — the renderer owns pixels). Supports box resize + rotate for
/// most layers, and endpoint editing for arrows/lines.
struct SelectionGizmoView: View {
    let model: EditorModel
    let layer: Layer
    let geom: CanvasGeometry
    let space: String

    @State private var startTransform: LayerTransform?
    @State private var interacting = false

    var body: some View {
        let t = layer.transform
        let center = geom.point(t.center)
        let halfW = t.size.width * geom.display.width / 2
        let halfH = t.size.height * geom.display.height / 2
        let rot = CGFloat(t.rotation)

        ZStack {
            switch gizmoKind {
            case .endpoint:
                endpointHandles
            case .freehand:
                outline(halfW: halfW, halfH: halfH, rot: rot, center: center, dashed: true)
            case .box:
                outline(halfW: halfW, halfH: halfH, rot: rot, center: center, dashed: false)
                ForEach(Corner.all, id: \.self) { corner in
                    handle
                        .position(cornerPoint(corner, center: center, halfW: halfW, halfH: halfH, rot: rot))
                        .gesture(resizeGesture(corner))
                }
                rotateHandleView(center: center, halfW: halfW, halfH: halfH, rot: rot)
            }
        }
    }

    // MARK: Kind

    private enum GizmoKind { case box, endpoint, freehand }
    private var gizmoKind: GizmoKind {
        if case .annotation(let a) = layer.content {
            if a.kind == .arrow || a.kind == .line { return .endpoint }
            if a.kind == .pen || a.kind == .highlighter { return .freehand }
        }
        if case .redaction(let r) = layer.content, r.path != nil { return .freehand }
        return .box
    }

    // MARK: Outline

    private func outline(halfW: CGFloat, halfH: CGFloat, rot: CGFloat, center: CGPoint, dashed: Bool) -> some View {
        Rectangle()
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [6, 4] : []))
            .frame(width: max(halfW * 2, 4), height: max(halfH * 2, 4))
            .rotationEffect(.radians(Double(rot)))
            .position(center)
            .allowsHitTesting(false)
    }

    // MARK: Handle visuals

    private var handle: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
            .frame(width: 20, height: 20)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .contentShape(Circle().inset(by: -8))
    }

    // MARK: Corner resize

    private enum Corner: Hashable, CaseIterable {
        case tl, tr, br, bl
        static let all: [Corner] = [.tl, .tr, .br, .bl]
        var sign: (x: CGFloat, y: CGFloat) {
            switch self {
            case .tl: return (-1, -1); case .tr: return (1, -1)
            case .br: return (1, 1);  case .bl: return (-1, 1)
            }
        }
    }

    private func cornerPoint(_ c: Corner, center: CGPoint, halfW: CGFloat, halfH: CGFloat, rot: CGFloat) -> CGPoint {
        vecAdd(center, rotateVec(CGPoint(x: c.sign.x * halfW, y: c.sign.y * halfH), rot))
    }

    private func resizeGesture(_ corner: Corner) -> some Gesture {
        DragGesture(coordinateSpace: .named(space))
            .onChanged { value in
                beginIfNeeded()
                guard let s = startTransform else { return }
                let sHalfW = s.size.width * geom.display.width / 2
                let sHalfH = s.size.height * geom.display.height / 2
                let c0 = geom.point(s.center)
                let opposite = vecAdd(c0, rotateVec(CGPoint(x: -corner.sign.x * sHalfW, y: -corner.sign.y * sHalfH), CGFloat(s.rotation)))
                let dragged = value.location
                let newCenter = CGPoint(x: (opposite.x + dragged.x) / 2, y: (opposite.y + dragged.y) / 2)
                let local = rotateVec(CGPoint(x: dragged.x - newCenter.x, y: dragged.y - newCenter.y), -CGFloat(s.rotation))
                let newHalfW = max(abs(local.x), 10)
                let newHalfH = max(abs(local.y), 10)
                model.updateSelectedLayerLive {
                    $0.transform.center = geom.norm(newCenter)
                    $0.transform.size = CGSize(width: newHalfW * 2 / geom.display.width,
                                               height: newHalfH * 2 / geom.display.height)
                }
            }
            .onEnded { _ in endInteraction() }
    }

    // MARK: Rotate

    private func rotateHandleView(center: CGPoint, halfW: CGFloat, halfH: CGFloat, rot: CGFloat) -> some View {
        let pos = vecAdd(center, rotateVec(CGPoint(x: 0, y: -halfH - 34), rot))
        return ZStack {
            Path { p in p.move(to: center); p.addLine(to: pos) }
                .stroke(Theme.accent.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
            Circle()
                .fill(Theme.accent)
                .overlay(Image(systemName: "arrow.trianglehead.clockwise").font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .contentShape(Circle().inset(by: -8))
                .position(pos)
                .gesture(
                    DragGesture(coordinateSpace: .named(space))
                        .onChanged { value in
                            beginIfNeeded()
                            let c = geom.point(layer.transform.center)
                            let angle = atan2(value.location.y - c.y, value.location.x - c.x)
                            var rot = Double(angle) + .pi / 2
                            let step = Double.pi / 12 // snap to 15°
                            let nearest = (rot / step).rounded() * step
                            if abs(rot - nearest) < 0.045 { rot = nearest }
                            model.updateSelectedLayerLive { $0.transform.rotation = rot }
                        }
                        .onEnded { _ in endInteraction() }
                )
        }
    }

    // MARK: Endpoint (arrow / line)

    private var endpointHandles: some View {
        Group {
            if case .annotation(let a) = layer.content, a.points.count >= 2 {
                let r = geom.rect(for: layer.transform)
                ForEach(0..<2, id: \.self) { i in
                    let p = CGPoint(x: r.minX + a.points[i].x * r.width, y: r.minY + a.points[i].y * r.height)
                    handle
                        .position(p)
                        .gesture(
                            DragGesture(coordinateSpace: .named(space))
                                .onChanged { value in
                                    beginIfNeeded()
                                    let n = geom.norm(value.location).clamped()
                                    model.updateSelectedLayerLive {
                                        guard case .annotation(var ann) = $0.content else { return }
                                        if ann.points.count >= 2 { ann.points[i] = n; $0.content = .annotation(ann) }
                                    }
                                }
                                .onEnded { _ in endInteraction() }
                        )
                }
            }
        }
    }

    // MARK: Interaction lifecycle

    private func beginIfNeeded() {
        guard !interacting else { return }
        interacting = true
        startTransform = layer.transform
        model.beginInteraction()
    }

    private func endInteraction() {
        guard interacting else { return }
        interacting = false
        startTransform = nil
        model.endInteraction()
    }
}

// MARK: - Vector helpers

private func rotateVec(_ v: CGPoint, _ angle: CGFloat) -> CGPoint {
    CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
}
private func vecAdd(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
