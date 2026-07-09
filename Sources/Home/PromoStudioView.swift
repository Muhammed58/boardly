import SwiftUI
import PhotosUI

/// "Promo Studio" — pick a template, add screenshots, and generate a
/// consistent multi-page set ready to customize.
struct PromoStudioView: View {
    let onGenerate: (Project) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PhotosPickerItem] = []
    @State private var importedIDs: [String] = []
    @State private var importedThumbs: [UIImage] = []
    @State private var templateID = PromoTemplates.all[0].id
    @State private var templateThumbs: [String: UIImage] = [:]
    @State private var placeholderID: String?

    private let grid = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("1. Pick a template")
                    templateGallery
                    section("2. Add your screenshots")
                    PhotosPicker(selection: $items, maxSelectionCount: 10, matching: .images) {
                        Label(importLabel, systemImage: "photo.stack")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Theme.accentSoft, in: Capsule())
                    }
                    .padding(.horizontal, Theme.Space.md)
                    if !importedThumbs.isEmpty {
                        LazyVGrid(columns: grid, spacing: 8) {
                            ForEach(Array(importedThumbs.enumerated()), id: \.offset) { _, image in
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(height: 100).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, Theme.Space.md)
                    } else {
                        Text("No screenshots? Generate a 3-page starter set with placeholders, then swap them in.")
                            .font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
                            .padding(.horizontal, Theme.Space.md)
                    }
                    Button { generate() } label: {
                        Label("Generate \(pageCount)-page set", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Promo Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .tint(Theme.accent)
        .task { await setup() }
        .onChange(of: items) { _, new in loadImports(new) }
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink).padding(.horizontal, Theme.Space.md)
    }

    private var templateGallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PromoTemplates.all) { template in
                    Button { templateID = template.id } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceSunk)
                                if let img = templateThumbs[template.id] { Image(uiImage: img).resizable().scaledToFit() }
                                else { ProgressView().controlSize(.small) }
                            }
                            .frame(width: 104, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(template.id == templateID ? Theme.accent : Theme.separator, lineWidth: template.id == templateID ? 3 : 1))
                            Text(template.name).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(template.id == templateID ? Theme.accent : Theme.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private var selected: PromoTemplate { PromoTemplates.template(templateID) }
    private var pageCount: Int { importedIDs.isEmpty ? 3 : importedIDs.count }
    private var importLabel: String { importedIDs.isEmpty ? "Choose screenshots" : "Change (\(importedIDs.count))" }

    private func setup() async {
        if placeholderID == nil { placeholderID = ImageStore.shared.save(SampleScreenshot.make()) }
        buildTemplateThumbs()
    }

    private func buildTemplateThumbs() {
        guard let placeholderID else { return }
        let h: CGFloat = 300
        var out: [String: UIImage] = [:]
        for template in PromoTemplates.all {
            let canvas = template.buildPage(imageID: importedIDs.first ?? placeholderID, headline: template.starters[0])
            let px = CGSize(width: h * canvas.aspect.ratio, height: h)
            out[template.id] = CanvasRenderer.shared.render(canvas, pixelSize: px, quality: .preview)
        }
        templateThumbs = out
    }

    private func loadImports(_ picked: [PhotosPickerItem]) {
        Task {
            var ids: [String] = []
            var thumbs: [UIImage] = []
            for item in picked {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data)?.normalizedUp() {
                    ids.append(ImageStore.shared.save(image))
                    thumbs.append(image)
                }
            }
            importedIDs = ids; importedThumbs = thumbs
            buildTemplateThumbs()
        }
    }

    private func generate() {
        let ids = importedIDs.isEmpty ? Array(repeating: placeholderID ?? ImageStore.shared.save(SampleScreenshot.make()), count: 3) : importedIDs
        onGenerate(PromoTemplates.generateSet(name: "Promo Set", template: selected, imageIDs: ids, now: Date()))
        dismiss()
    }
}
