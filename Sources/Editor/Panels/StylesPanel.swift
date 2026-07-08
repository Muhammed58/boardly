import SwiftUI

/// One-tap complete looks with live-rendered thumbnails, plus your saved
/// presets. Each thumbnail is the real render pipeline applied to your screenshot.
struct StylesPanel: View {
    let model: EditorModel
    @Environment(LibraryStore.self) private var library
    @State private var thumbs: [String: UIImage] = [:]
    private let thumbW: CGFloat = 92
    private let thumbH: CGFloat = 116

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                saveTile
                ForEach(library.savedStyles) { saved in savedTile(saved) }
                ForEach(StyleCatalog.all) { style in styleTile(style) }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 12)
        }
        .task(id: thumbKey) { buildThumbs() }
    }

    private var saveTile: some View {
        Button { library.saveStyle(CanvasLook.from(model.canvas), name: "Style \(library.savedStyles.count + 1)") } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentSoft)
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .semibold))
                        Text("Save").font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(Theme.accent)
                }
                .frame(width: thumbW, height: thumbH)
                Text("Current").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func savedTile(_ saved: SavedStyle) -> some View {
        Button { saved.look.apply(to: model) } label: { tile(name: saved.name, key: "saved-\(saved.id)") }
            .buttonStyle(.plain)
            .contextMenu { Button(role: .destructive) { library.deleteStyle(saved.id) } label: { Label("Delete", systemImage: "trash") } }
    }

    private func styleTile(_ style: CompleteStyle) -> some View {
        Button { StyleCatalog.apply(style, to: model) } label: { tile(name: style.name, key: style.id) }
            .buttonStyle(.plain)
    }

    private func tile(name: String, key: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceSunk)
                if let img = thumbs[key] { Image(uiImage: img).resizable().scaledToFill() }
                else { ProgressView().controlSize(.small) }
            }
            .frame(width: thumbW, height: thumbH)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.separator, lineWidth: 1))
            Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.inkSecondary).lineLimit(1)
        }
    }

    private var thumbKey: String { "\(model.screenshotID?.uuidString ?? "")-\(library.savedStyles.count)" }

    private func buildThumbs() {
        guard model.screenshotID != nil else { return }
        let ratio = model.canvas.aspect.ratio
        let h = thumbH * 2
        let px = CGSize(width: max(h * ratio, 8), height: h)
        var out: [String: UIImage] = [:]
        for style in StyleCatalog.all {
            out[style.id] = CanvasRenderer.shared.render(style.look.previewCanvas(base: model.canvas), pixelSize: px, quality: .preview)
        }
        for saved in library.savedStyles {
            out["saved-\(saved.id)"] = CanvasRenderer.shared.render(saved.look.previewCanvas(base: model.canvas), pixelSize: px, quality: .preview)
        }
        thumbs = out
    }
}
