import SwiftUI

/// Draw tools: arrows, lines, boxes, circles, freehand pen, highlighter, and
/// numbered step badges. Drag-defined kinds arm the canvas; steps drop at center.
struct AnnotatePanel: View {
    let model: EditorModel

    private let dragKinds: [AnnotationKind] = [.arrow, .line, .rectangle, .ellipse, .pen, .highlighter]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dragKinds) { kind in
                            AddToolButton(title: kind.displayName, systemImage: kind.symbol, active: isPending(kind)) {
                                model.pending = .annotation(kind)
                            }
                        }
                        AddToolButton(title: "Step", systemImage: "number.circle.fill") { placeStep() }
                        AddToolButton(title: "Magnify", systemImage: "plus.magnifyingglass", active: model.pending == .magnifier) {
                            model.pending = .magnifier
                        }
                        AddToolButton(title: "Callout", systemImage: "bubble.left.fill") {
                            model.addLayer(LayerFactory.callout(at: CGPoint(x: 0.5, y: 0.4)))
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                }

                colorRow

                if let a = model.selectedAnnotation {
                    EditSlider(title: "Thickness", value: Binding(
                        get: { a.strokeWidth }, set: { v in model.updateSelectedAnnotation(live: true) { $0.strokeWidth = v } }),
                        range: 0.002...0.03, onEditing: { model.slider(begin: $0) })
                        .padding(.horizontal, Theme.Space.md)
                    if a.kind == .rectangle || a.kind == .ellipse {
                        Toggle("Filled", isOn: Binding(
                            get: { a.filled }, set: { v in model.updateSelectedAnnotation { $0.filled = v } }))
                            .font(.system(size: 13, weight: .medium))
                            .tint(Theme.accent)
                            .padding(.horizontal, Theme.Space.md)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { model.eyedropper = true } label: {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(model.eyedropper ? .white : Theme.accent)
                        .frame(width: 28, height: 28)
                        .background(model.eyedropper ? Theme.accent : Theme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                ForEach(ToolPalette.colors, id: \.self) { color in
                    ColorDot(color: color, selected: model.toolColor == color) {
                        model.toolColor = color
                        if model.selectedAnnotation != nil { model.updateSelectedAnnotation { $0.color = color } }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private func isPending(_ kind: AnnotationKind) -> Bool {
        model.pending == .annotation(kind)
    }

    private func placeStep() {
        let count = model.canvas.layers.filter {
            if case .annotation(let a) = $0.content { return a.kind == .numberBadge }; return false
        }.count
        var content = AnnotationContent(kind: .numberBadge, color: model.toolColor, points: [], number: count + 1)
        content.strokeWidth = 0
        let layer = Layer(name: "Step",
                          transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.4), size: CGSize(width: 0.13, height: 0.13)),
                          content: .annotation(content))
        model.addLayer(layer)
    }
}
