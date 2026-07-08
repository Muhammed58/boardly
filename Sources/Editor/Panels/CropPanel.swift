import SwiftUI

/// Output size / aspect ratio for social + App Store, grouped by use.
struct CropPanel: View {
    let model: EditorModel
    @State private var showCrop = false
    @State private var straighten: Double = 0
    @State private var appStoreThumbs: [String: UIImage] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                imageTools
                appStoreSection

                ForEach(CanvasAspect.groups, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.uppercased())
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkTertiary)
                            .padding(.horizontal, Theme.Space.md)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(aspects(in: group)) { aspect in
                                    aspectChip(aspect)
                                }
                            }
                            .padding(.horizontal, Theme.Space.md)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showCrop) {
            if let image = model.screenshotImage {
                CropSheet(image: image) { rect in
                    model.transformScreenshotImage { $0.cropped(normalizedRect: rect) }
                }
            }
        }
        .task(id: model.screenshotID) { buildAppStoreThumbs() }
    }

    @ViewBuilder private var appStoreSection: some View {
        HStack {
            Text("APP STORE TEMPLATES").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkTertiary)
            Spacer()
            if model.pageCount > 1 {
                Button { model.syncAllPages() } label: {
                    Label("Sync all pages", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.horizontal, Theme.Space.md)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AppStoreTemplates.all) { template in
                    Button { model.applyTemplateToCurrentPage(template) } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.surfaceSunk)
                                if let img = appStoreThumbs[template.id] { Image(uiImage: img).resizable().scaledToFit() }
                            }
                            .frame(width: 52, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.separator, lineWidth: 1))
                            Text(template.name).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private func buildAppStoreThumbs() {
        guard let imageID = model.screenshotContent?.imageID else { return }
        let h: CGFloat = 160
        var out: [String: UIImage] = [:]
        for template in AppStoreTemplates.all {
            let canvas = template.buildPage(imageID: imageID, headline: template.starters[0])
            out[template.id] = CanvasRenderer.shared.render(canvas, pixelSize: CGSize(width: h * canvas.aspect.ratio, height: h), quality: .preview)
        }
        appStoreThumbs = out
    }

    private var imageTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PanelChip(title: "Crop", systemImage: "crop", selected: false) { showCrop = true }
                    PanelChip(title: "Flip H", systemImage: "arrow.left.and.right", selected: false) {
                        model.transformScreenshotImage { $0.flipped(horizontal: true) }
                    }
                    PanelChip(title: "Flip V", systemImage: "arrow.up.and.down", selected: false) {
                        model.transformScreenshotImage { $0.flipped(horizontal: false) }
                    }
                    PanelChip(title: "Rotate", systemImage: "rotate.right", selected: false) {
                        model.transformScreenshotImage { $0.rotated90(clockwise: true) }
                    }
                }
                .padding(.horizontal, Theme.Space.md)
            }
            EditSlider(title: "Straighten \(Int(straighten))°", value: $straighten, range: -15...15, onEditing: { editing in
                if !editing && abs(straighten) > 0.1 {
                    model.transformScreenshotImage { $0.straightened(degrees: CGFloat(straighten)) }
                    straighten = 0
                }
            })
            .padding(.horizontal, Theme.Space.md)
        }
    }

    private func aspects(in group: String) -> [CanvasAspect] {
        CanvasAspect.all.filter { $0.group == group }
    }

    private func aspectChip(_ aspect: CanvasAspect) -> some View {
        let selected = model.canvas.aspect.id == aspect.id
        return Button { model.setAspect(aspect) } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(selected ? Theme.accent : Theme.inkTertiary, lineWidth: selected ? 2.5 : 1.5)
                    .frame(width: previewSize(aspect).width, height: previewSize(aspect).height)
                    .frame(width: 46, height: 46)
                Text(aspect.name).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.inkSecondary)
            }
            .frame(width: 74)
        }
        .buttonStyle(.plain)
    }

    private func previewSize(_ aspect: CanvasAspect) -> CGSize {
        let maxDim: CGFloat = 40
        let r = aspect.ratio
        return r >= 1 ? CGSize(width: maxDim, height: maxDim / r) : CGSize(width: maxDim * r, height: maxDim)
    }

    /// One-tap App Store shot: tall canvas, framed screenshot, headline text.
    private func applyAppStoreTemplate() {
        model.edit { canvas in
            canvas.aspect = .appStore67
            if let id = canvas.primaryScreenshot?.id, var layer = canvas[id],
               case .screenshot(var s) = layer.content {
                s.frame = .iphone
                s.shadow = .strong
                layer.content = .screenshot(s)
                layer.transform.center = CGPoint(x: 0.5, y: 0.64)
                layer.transform.size = CGSize(width: 0.82, height: 0.82)
                canvas[id] = layer
            }
            var headline = TextContent()
            headline.string = "Your headline here"
            headline.weight = .heavy
            headline.fontSize = 0.045
            headline.color = .white
            headline.hasShadow = false
            canvas.layers.append(Layer(
                name: "Headline",
                transform: LayerTransform(center: CGPoint(x: 0.5, y: 0.13), size: CGSize(width: 0.86, height: 0.16)),
                content: .text(headline)))
        }
    }
}
