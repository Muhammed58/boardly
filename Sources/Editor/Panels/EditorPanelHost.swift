import SwiftUI

/// Hosts the panel for the active tool plus a contextual actions bar for the
/// selected layer. Fixed height so the canvas area doesn't jump.
struct EditorPanelHost: View {
    let model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            if let selected = model.selectedLayer {
                LayerActionsBar(model: model, layer: selected)
                Divider().overlay(Theme.separator.opacity(0.6))
            }
            panel
                .frame(maxWidth: .infinity)
                .frame(height: 176)
        }
        .background(Theme.surface)
        .overlay(alignment: .top) { Divider().overlay(Theme.separator) }
    }

    @ViewBuilder private var panel: some View {
        switch model.activeTool {
        case .styles: StylesPanel(model: model)
        case .background: BackgroundPanel(model: model)
        case .frame: FramePanel(model: model)
        case .text: TextPanel(model: model)
        case .annotate: AnnotatePanel(model: model)
        case .redact: RedactPanel(model: model)
        case .spotlight: SpotlightPanel(model: model)
        case .sticker: StickerPanel(model: model)
        case .crop: CropPanel(model: model)
        case .layers: LayersPanel(model: model)
        }
    }
}

/// Compact row of actions for the selected layer.
struct LayerActionsBar: View {
    let model: EditorModel
    let layer: Layer

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: layer.symbol).font(.system(size: 13, weight: .semibold))
                Text(layer.kindLabel).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.ink)
            Spacer()
            action("square.on.square", "Duplicate") { model.duplicateSelected() }
            action("arrow.up.to.line.compact", "Front") { model.reorderSelected(1) }
            action("arrow.down.to.line.compact", "Back") { model.reorderSelected(-1) }
            action("trash", "Delete", tint: .red) { model.deleteSelected() }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, 9)
    }

    private func action(_ symbol: String, _ label: String, tint: Color = Theme.inkSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(tint)
        }
        .accessibilityLabel(label)
    }
}
