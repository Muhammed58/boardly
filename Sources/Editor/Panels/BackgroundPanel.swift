import SwiftUI

/// Backdrop chooser: preset gradients / mesh / solids, a custom color, and the
/// blurred-screenshot look.
struct BackgroundPanel: View {
    let model: EditorModel
    @Environment(LibraryStore.self) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ColorPicker(selection: customColorBinding, supportsOpacity: false) {
                        Text("Custom").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                    }
                    .fixedSize()
                    PanelChip(title: "Match", systemImage: "wand.and.stars.inverse", selected: false) { matchToScreenshot() }
                    PanelChip(title: "Blur shot", systemImage: "drop.fill", selected: isBlurred) {
                        model.setBackground(.blurredScreenshot(radius: 0.06))
                    }
                    if library.hasBrand {
                        PanelChip(title: "Brand", systemImage: "star.fill", selected: false) {
                            model.setBackground(.linearGradient(colors: library.brandColors, angle: 135))
                        }
                    } else {
                        PanelChip(title: "Set brand", systemImage: "star", selected: false) {
                            library.setBrand(colors: BackgroundPreset.swatchColors(for: model.canvas.background), logoID: nil)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Space.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(BackgroundPresets.all, id: \.0) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.0.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.inkTertiary)
                                HStack(spacing: 8) {
                                    ForEach(group.1) { preset in swatch(preset) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                }

                HStack(spacing: 16) {
                    EditSlider(title: "Vignette", value: effectBinding(\.vignette), range: 0...1, onEditing: { model.slider(begin: $0) })
                    EditSlider(title: "Grain", value: effectBinding(\.grain), range: 0...1, onEditing: { model.slider(begin: $0) })
                }
                .padding(.horizontal, Theme.Space.md)

                PanelChip(title: "Watermark", systemImage: "signature", selected: model.canvas.watermark != nil) {
                    model.edit { $0.watermark = $0.watermark == nil ? WatermarkSpec() : nil }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, 6)
            }
            .padding(.vertical, 12)
        }
    }

    private func effectBinding(_ keyPath: WritableKeyPath<EditorCanvas, Double?>) -> Binding<Double> {
        Binding(
            get: { model.canvas[keyPath: keyPath] ?? 0 },
            set: { v in model.updateLive { $0[keyPath: keyPath] = v < 0.02 ? nil : v } }
        )
    }

    private func matchToScreenshot() {
        guard let id = model.screenshotID,
              case .screenshot(let s)? = model.project.canvas[id]?.content,
              let image = ImageStore.shared.image(for: s.imageID) else { return }
        let colors = image.dominantColors(3)
        if colors.count >= 2 { model.setBackground(.linearGradient(colors: colors, angle: 135)) }
    }

    private func swatch(_ preset: BackgroundPreset) -> some View {
        Button { model.setBackground(preset.style) } label: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.clear)
                .frame(width: 50, height: 50)
                .overlay(
                    BackgroundStylePreview(style: preset.style)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected(preset) ? Theme.accent : Theme.separator,
                                lineWidth: isSelected(preset) ? 3 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ preset: BackgroundPreset) -> Bool { model.canvas.background == preset.style }

    private var isBlurred: Bool {
        if case .blurredScreenshot = model.canvas.background { return true }; return false
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { if case .solid(let c) = model.canvas.background { return c.color }; return .white },
            set: { model.setBackground(.solid(RGBAColor($0))) }
        )
    }
}
