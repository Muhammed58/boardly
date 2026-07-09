import SwiftUI
import PhotosUI

/// Page switcher for multi-page projects (promo sets). Shown when a project
/// has more than one page.
struct PageBar: View {
    let model: EditorModel
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<model.pageCount, id: \.self) { index in
                        pageChip(index)
                    }
                }
                .padding(.leading, Theme.Space.md)
            }
            Spacer(minLength: 0)
            Button { model.duplicateCurrentPage() } label: {
                Image(systemName: "plus.square.on.square").font(.system(size: 16)).foregroundStyle(Theme.accent)
            }
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.accent)
            }
            .padding(.trailing, Theme.Space.md)
        }
        .frame(height: 44)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Divider().overlay(Theme.separator) }
        .onChange(of: photoItem) { _, item in addPageFromPhoto(item) }
    }

    private func pageChip(_ index: Int) -> some View {
        let isCurrent = index == model.pageIndex
        return Button { model.selectPage(index) } label: {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: 30)
                .foregroundStyle(isCurrent ? Color.white : Theme.inkSecondary)
                .background(isCurrent ? Theme.accent : Theme.surfaceSunk, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if model.pageCount > 1 {
                Button(role: .destructive) { model.deletePage(index) } label: { Label("Delete page", systemImage: "trash") }
            }
        }
    }

    private func addPageFromPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)?.normalizedUp() else { return }
            let id = ImageStore.shared.save(image)
            var canvas = EditorCanvas.beautified(imageID: id, imageSize: image.size)
            CanvasLook.from(model.canvas).applyTo(&canvas)
            model.addPage(canvas)
        }
    }
}
