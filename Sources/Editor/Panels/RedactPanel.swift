import SwiftUI

/// Privacy tools: drag to blur / pixelate / black-box a region, or one-tap
/// auto-redact detected emails, numbers, tokens, and faces.
struct RedactPanel: View {
    let model: EditorModel
    @State private var isDetecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(RedactionStyle.allCases) { style in
                            AddToolButton(title: style.displayName, systemImage: style.symbol,
                                          active: model.pending == .redaction(style)) {
                                model.pending = .redaction(style)
                            }
                        }
                        AddToolButton(title: "Mosaic", systemImage: "scribble.variable", active: model.pending == .mosaicBrush) {
                            model.pending = .mosaicBrush
                        }
                        AddToolButton(title: isDetecting ? "Scanning…" : "Auto", systemImage: "sparkles") {
                            autoDetect()
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                }

                if let r = model.selectedRedaction {
                    EditSlider(title: r.style == .pixelate ? "Block size" : "Strength", value: Binding(
                        get: { r.intensity }, set: { v in model.updateSelectedRedaction(live: true) { $0.intensity = v } }),
                        range: 0.004...0.06, onEditing: { model.slider(begin: $0) })
                        .padding(.horizontal, Theme.Space.md)
                    HStack(spacing: 8) {
                        ForEach(RedactionStyle.allCases) { style in
                            PanelChip(title: style.displayName, selected: r.style == style) {
                                model.updateSelectedRedaction { $0.style = style }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                } else {
                    Text("Drag on the canvas to hide a region, or tap Auto.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, Theme.Space.md)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func autoDetect() {
        guard !isDetecting,
              let id = model.screenshotID,
              case .screenshot(let s)? = model.project.canvas[id]?.content,
              let layer = model.project.canvas[id],
              let image = ImageStore.shared.image(for: s.imageID) else { return }
        isDetecting = true
        let host = layer.transform
        Task {
            let rects = await SensitiveContentDetector.detect(in: image)
            defer { isDetecting = false }
            guard !rects.isEmpty else { return }
            model.edit { canvas in
                for r in rects {
                    // Map image-space rect (0…1) into canvas space via the screenshot's box.
                    let left = host.center.x - host.size.width / 2
                    let top = host.center.y - host.size.height / 2
                    let center = CGPoint(x: left + (r.midX) * host.size.width,
                                         y: top + (r.midY) * host.size.height)
                    let size = CGSize(width: r.width * host.size.width, height: r.height * host.size.height)
                    let content = RedactionContent(style: .blur, intensity: 0.02)
                    canvas.layers.append(Layer(name: "Redaction",
                                               transform: LayerTransform(center: center, size: size),
                                               content: .redaction(content)))
                }
            }
        }
    }
}
