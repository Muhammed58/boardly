import SwiftUI

/// The full-screen editor: top bar + live canvas + per-tool panel + tool bar.
/// The canvas is produced by the single render pipeline; this view supplies
/// chrome and hosts tool panels.
struct EditorView: View {
    let onSave: (Project, UIImage?) -> Void
    @State private var model: EditorModel
    @State private var showExport = false
    @Environment(\.dismiss) private var dismiss

    init(project: Project, onSave: @escaping (Project, UIImage?) -> Void) {
        let model = EditorModel(project: project)
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["BOARDLY_TOOL"], let tool = EditorTool(rawValue: raw) {
            model.activeTool = tool
        }
        if ProcessInfo.processInfo.environment["BOARDLY_CLEAN"] == "1" { model.selectedLayerID = nil }
        #endif
        _model = State(initialValue: model)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.separator)
            if model.pageCount > 1 { PageBar(model: model) }
            EditorCanvasView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            EditorPanelHost(model: model)
        }
        // Tool bar is pinned above the home indicator; its surface fills the
        // bottom safe area so it reads as a proper anchored bar on every device.
        .safeAreaInset(edge: .bottom, spacing: 0) { toolBar }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showExport) { ExportSheet(model: model) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Theme.Space.lg) {
            Button { save(); dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            Button { model.duplicateCurrentPage() } label: { Image(systemName: "plus.rectangle.on.rectangle") }
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
            Button { showExport = true } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold))
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, 12)
    }

    // MARK: Tool bar

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        model.activeTool = tool
                        model.pending = nil
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.symbol).font(.system(size: 19))
                            Text(tool.title).font(.system(size: 10, weight: .medium))
                        }
                        .frame(width: 64, height: 52)
                        .foregroundStyle(model.activeTool == tool ? Theme.accent : Theme.inkSecondary)
                        .background(
                            model.activeTool == tool ? Theme.accentSoft : .clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.Space.sm)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider().overlay(Theme.separator) }
    }

    // MARK: Actions

    private func save() {
        model.commitCurrentPage()
        let thumb = CanvasRenderer.shared.render(model.canvas, pixelSize: thumbnailSize(), quality: .preview)
        onSave(model.project, thumb)
    }

    private func thumbnailSize() -> CGSize {
        let target: CGFloat = 420
        let ratio = model.canvas.aspect.ratio
        return ratio >= 1
            ? CGSize(width: target, height: target / ratio)
            : CGSize(width: target * ratio, height: target)
    }
}
