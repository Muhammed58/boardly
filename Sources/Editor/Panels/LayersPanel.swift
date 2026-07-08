import SwiftUI
import PhotosUI

/// Layer list (top layer first): select, toggle visibility, delete. Also the
/// entry point for collage — add more screenshots as layers.
struct LayersPanel: View {
    let model: EditorModel
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Add image (collage)", systemImage: "plus.rectangle.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.accentSoft, in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                .padding(.bottom, 4)

                if model.canvas.layers.isEmpty {
                    Text("No layers yet").font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 12)
                }
                ForEach(model.canvas.layers.reversed()) { layer in
                    row(layer)
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 10)
        }
        .onChange(of: photoItem) { _, item in addImage(item) }
    }

    private func addImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)?.normalizedUp() else { return }
            let id = ImageStore.shared.save(image)
            let layer = LayerFactory.screenshot(imageID: id,
                                                imageAspect: image.size.aspect,
                                                canvasRatio: model.canvas.aspect.ratio,
                                                widthFrac: 0.5,
                                                center: CGPoint(x: 0.5, y: 0.5))
            model.addLayer(layer)
        }
    }

    private func row(_ layer: Layer) -> some View {
        let selected = model.selectedLayerID == layer.id
        return HStack(spacing: 12) {
            Image(systemName: layer.symbol)
                .font(.system(size: 14))
                .foregroundStyle(selected ? Theme.accent : Theme.inkSecondary)
                .frame(width: 22)
            Text(layer.name).font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                model.editSelectedLayerVisibility(layer.id)
            } label: {
                Image(systemName: layer.isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 14)).foregroundStyle(Theme.inkTertiary)
            }
            Button { model.deleteLayer(layer.id) } label: {
                Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(selected ? Theme.accentSoft : Theme.surfaceSunk,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { model.selectedLayerID = layer.id }
    }
}
