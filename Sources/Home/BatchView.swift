import SwiftUI
import PhotosUI

/// Batch mode: import several screenshots, pick one style, export the whole set.
struct BatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var styleID: String = StyleCatalog.all[1].id
    @State private var working = false
    @State private var toast: String?
    @State private var share: SharePayload?

    private let grid = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PhotosPicker(selection: $items, maxSelectionCount: 12, matching: .images) {
                        Label(images.isEmpty ? "Choose screenshots" : "Add / change (\(images.count))", systemImage: "photo.stack")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if !images.isEmpty {
                        Text("STYLE").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StyleCatalog.all) { style in
                                    PanelChip(title: style.name, selected: style.id == styleID) { styleID = style.id }
                                }
                            }
                        }
                        LazyVGrid(columns: grid, spacing: 10) {
                            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                                Color.clear
                                    .frame(height: 120)
                                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        VStack(spacing: 10) {
                            Button { Task { await exportAll(toPhotos: true) } } label: {
                                Label("Save all to Photos", systemImage: "square.and.arrow.down")
                            }.buttonStyle(PrimaryButtonStyle())
                            Button { Task { await exportAll(toPhotos: false) } } label: {
                                Label("Share all", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                                    .background(Theme.surfaceSunk, in: Capsule())
                            }
                        }
                        .disabled(working)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .overlay { if working { ProgressView("Exporting…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.hud, in: Capsule()).padding(.bottom, 24)
                }
            }
        }
        .tint(Theme.accent)
        .sheet(item: $share) { ActivityView(items: $0.items) }
        .onChange(of: items) { _, new in loadImages(new) }
    }

    private var style: CompleteStyle { StyleCatalog.all.first { $0.id == styleID } ?? StyleCatalog.all[0] }

    private func loadImages(_ picked: [PhotosPickerItem]) {
        Task {
            var loaded: [UIImage] = []
            for item in picked {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    loaded.append(image.normalizedUp())
                }
            }
            images = loaded
        }
    }

    private func styled(_ image: UIImage) -> UIImage {
        let id = ImageStore.shared.save(image)
        let base = EditorCanvas.beautified(imageID: id, imageSize: image.size)
        let canvas = StyleCatalog.previewCanvas(base: base, style: style)
        return CanvasRenderer.shared.render(canvas, pixelSize: canvas.pixelSize, quality: .export)
    }

    private func exportAll(toPhotos: Bool) async {
        working = true; defer { working = false }
        if toPhotos {
            var saved = 0
            for image in images { if await Exporter.saveToPhotos(styled(image), pngData: nil) { saved += 1 } }
            flash("Saved \(saved) to Photos")
        } else {
            let urls = images.enumerated().compactMap { i, image -> URL? in
                styled(image).jpegData(compressionQuality: 0.95).flatMap { Exporter.writeTemp($0, ext: "jpg", name: "Boardly-\(i + 1)") }
            }
            if urls.isEmpty { flash("Export failed") } else { share = SharePayload(items: urls) }
        }
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        Task { try? await Task.sleep(nanoseconds: 1_800_000_000); withAnimation { toast = nil } }
    }
}
