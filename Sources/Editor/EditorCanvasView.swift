import SwiftUI

/// The interactive canvas: shows the single-render-path preview and hosts all
/// direct-manipulation gestures (select, move, and create-by-drag). Resize /
/// rotate / endpoint editing live in `SelectionGizmoView` on top.
struct EditorCanvasView: View {
    let model: EditorModel
    static let space = "boardly.canvas"

    @State private var rendered: UIImage?
    @State private var session: CanvasSession = .idle
    @State private var guideV = false
    @State private var guideH = false

    private enum CanvasSession: Equatable {
        case idle
        case move(UUID, CGPoint)          // layer, start center
        case placementDrag(UUID, CGPoint) // layer, start point
        case freehand(UUID)
        case tapEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let display = displayRect(in: geo.size)
            let geom = CanvasGeometry(display: display)
            ZStack(alignment: .topLeading) {
                canvasImage(display)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(mainDrag(geom))
                if let selected = model.selectedLayer {
                    SelectionGizmoView(model: model, layer: selected, geom: geom, space: Self.space)
                }
                if model.pending != nil { placementHint(display) }
                guidesOverlay(display)
            }
            .coordinateSpace(name: Self.space)
            .onAppear { render(display) }
            .onChange(of: model.project.canvas) { render(display) }
            .onChange(of: geo.size) { render(display) }
        }
    }

    // MARK: Preview

    private func canvasImage(_ display: CGRect) -> some View {
        Group {
            if let rendered {
                Image(uiImage: rendered)
                    .interpolation(.high)
                    .resizable()
                    .frame(width: display.width, height: display.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Theme.separator.opacity(0.6), lineWidth: 1)
                    )
                    .position(x: display.midX, y: display.midY)
            }
        }
    }

    private func placementHint(_ display: CGRect) -> some View {
        Text("Draw on the canvas")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.accent, in: Capsule())
            .position(x: display.midX, y: display.minY + 22)
            .allowsHitTesting(false)
    }

    private func displayRect(in size: CGSize) -> CGRect {
        let inset = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
        return inset.fitting(aspect: model.canvas.aspect.ratio)
    }

    // MARK: Rendering

    private func render(_ display: CGRect) {
        guard display.width > 2, display.height > 2 else { return }
        let scale: CGFloat = 2
        let px = CGSize(width: display.width * scale, height: display.height * scale)
        rendered = CanvasRenderer.shared.render(model.canvas, pixelSize: px, quality: .preview)
    }

    // MARK: Main gesture

    private func mainDrag(_ geom: CanvasGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if session == .idle { beginGesture(value, geom) }
                updateGesture(value, geom)
            }
            .onEnded { _ in endGesture() }
    }

    private func beginGesture(_ value: DragGesture.Value, _ geom: CanvasGeometry) {
        let start = geom.norm(value.startLocation)
        if model.eyedropper {
            if let rendered, let color = rendered.pixelColor(atNormalized: start.clamped()) {
                model.toolColor = color
                if model.selectedAnnotation != nil { model.updateSelectedAnnotation { $0.color = color } }
                if model.selectedText != nil { model.updateSelectedText { $0.color = color } }
            }
            model.eyedropper = false
            session = .tapEmpty
            return
        }
        if let pending = model.pending {
            beginPlacement(pending, at: start)
            return
        }
        if let hit = geom.hitTest(value.startLocation, layers: model.canvas.layers) {
            model.selectedLayerID = hit.id
            model.beginInteraction()
            session = .move(hit.id, hit.transform.center)
        } else {
            model.selectedLayerID = nil
            session = .tapEmpty
        }
    }

    private func updateGesture(_ value: DragGesture.Value, _ geom: CanvasGeometry) {
        switch session {
        case .move(_, let startCenter):
            let d = geom.normSize(value.translation)
            var c = CGPoint(x: startCenter.x + d.width, y: startCenter.y + d.height)
            updateGuides(applySnap(&c))
            model.updateSelectedLayerLive { $0.transform.center = clamp(c) }
        case .placementDrag(let id, let start):
            let cur = geom.norm(value.location)
            updatePlacementGeometry(id: id, from: start, to: cur)
        case .freehand(let id):
            appendFreehand(id: id, point: geom.norm(value.location))
        case .idle, .tapEmpty:
            break
        }
    }

    private func endGesture() {
        switch session {
        case .move, .placementDrag, .freehand:
            model.endInteraction()
            model.pending = nil
        case .idle, .tapEmpty:
            break
        }
        session = .idle
        guideV = false; guideH = false
    }

    // MARK: Snapping

    private func applySnap(_ c: inout CGPoint) -> (v: Bool, h: Bool) {
        let t: CGFloat = 0.012
        var v = false, h = false
        for target in [CGFloat(0.5)] where abs(c.x - target) < t { c.x = target; v = true }
        for target in [CGFloat(0.5)] where abs(c.y - target) < t { c.y = target; h = true }
        return (v, h)
    }

    private func updateGuides(_ snapped: (v: Bool, h: Bool)) {
        if snapped.v && !guideV { Haptics.snap() }
        if snapped.h && !guideH { Haptics.snap() }
        guideV = snapped.v; guideH = snapped.h
    }

    @ViewBuilder private func guidesOverlay(_ display: CGRect) -> some View {
        if guideV {
            Rectangle().fill(Theme.accent).frame(width: 1, height: display.height)
                .position(x: display.midX, y: display.midY).allowsHitTesting(false)
        }
        if guideH {
            Rectangle().fill(Theme.accent).frame(width: display.width, height: 1)
                .position(x: display.midX, y: display.midY).allowsHitTesting(false)
        }
    }

    // MARK: Placement

    private func beginPlacement(_ pending: PendingCreation, at start: CGPoint) {
        model.beginInteraction()
        if pending.isFreehand {
            let layer: Layer
            if case .mosaicBrush = pending {
                layer = LayerFactory.mosaicFreehand(color: model.toolColor, first: start)
            } else if case .annotation(let kind) = pending {
                layer = LayerFactory.freehand(kind, color: model.toolColor, first: start)
            } else {
                layer = LayerFactory.make(pending, from: start, to: start, color: model.toolColor)
            }
            model.updateLive { $0.layers.append(layer) }
            model.selectedLayerID = layer.id
            session = .freehand(layer.id)
            return
        }
        let layer = LayerFactory.make(pending, from: start, to: start, color: model.toolColor)
        model.updateLive { $0.layers.append(layer) }
        model.selectedLayerID = layer.id
        if pending.isDragDefined {
            session = .placementDrag(layer.id, start)
        } else {
            model.endInteraction()
            model.pending = nil
            session = .idle
        }
    }

    private func updatePlacementGeometry(id: UUID, from start: CGPoint, to cur: CGPoint) {
        model.updateLive { canvas in
            guard var layer = canvas[id] else { return }
            if case .annotation(var a) = layer.content, a.kind == .arrow || a.kind == .line {
                a.points = [start, cur]
                layer.content = .annotation(a)
            } else {
                let w = max(abs(cur.x - start.x), 0.02)
                let h = max(abs(cur.y - start.y), 0.02)
                let center = CGPoint(x: (start.x + cur.x) / 2, y: (start.y + cur.y) / 2)
                layer.transform.center = center
                layer.transform.size = CGSize(width: w, height: h)
                if case .magnifier(var m) = layer.content { m.source = center; layer.content = .magnifier(m) }
            }
            canvas[id] = layer
        }
    }

    private func appendFreehand(id: UUID, point: CGPoint) {
        model.updateLive { canvas in
            guard var layer = canvas[id] else { return }
            let p = point.clamped()
            switch layer.content {
            case .annotation(var a):
                if let last = a.points.last, last.distance(to: p) < 0.004 { return }
                a.points.append(p); layer.content = .annotation(a)
            case .redaction(var r):
                var path = r.path ?? []
                if let last = path.last, last.distance(to: p) < 0.004 { return }
                path.append(p); r.path = path; layer.content = .redaction(r)
            default:
                return
            }
            canvas[id] = layer
        }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, -0.1), 1.1), y: min(max(p.y, -0.1), 1.1))
    }
}
