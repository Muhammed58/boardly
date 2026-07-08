import SwiftUI

/// Export options: format, resolution, transparency, watermark, and the export
/// actions (Save to Photos, Share, Copy, Instagram carousel).
struct ExportSheet: View {
    let model: EditorModel
    @Environment(\.dismiss) private var dismiss

    @State private var format: ExportFormat = .png
    @State private var scale: CGFloat = 2
    @State private var transparent = false
    @State private var carouselCount = 3
    @State private var preview: UIImage?
    @State private var share: SharePayload?
    @State private var toast: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    previewCard
                    picker("Format", ExportFormat.allCases.map(\.label), selection: formatIndex)
                    picker("Resolution", ["1×", "2×", "3×"], selection: scaleIndex)
                    if format.supportsTransparency {
                        Toggle("Transparent background", isOn: $transparent).tint(Theme.accent).font(.system(size: 15, weight: .medium))
                    }
                    Toggle("Watermark", isOn: watermarkBinding).tint(Theme.accent).font(.system(size: 15, weight: .medium))
                    actions
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
        .tint(Theme.accent)
        .sheet(item: $share) { ActivityView(items: $0.items) }
        .task(id: previewKey) { rebuildPreview() }
        .overlay(alignment: .bottom) { toastView }
    }

    // MARK: Sections

    private var previewCard: some View {
        ZStack {
            Checkerboard().opacity(transparent ? 1 : 0)
            if let preview {
                Image(uiImage: preview).resizable().scaledToFit()
            } else { ProgressView() }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .background(Theme.surfaceSunk, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { Task { await saveToPhotos() } } label: {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(PrimaryButtonStyle())
            HStack(spacing: 10) {
                secondary("Share", "square.and.arrow.up") { Task { await shareExport() } }
                secondary("Copy", "doc.on.doc") { Task { await copyExport() } }
            }
            secondary("Carousel × \(carouselCount)", "square.grid.3x1.below.line.grid.1x2") { Task { await shareCarousel() } }
            if model.pageCount > 1 {
                secondary("Save all \(model.pageCount) pages", "square.stack.3d.up.fill") { Task { await exportAllPages() } }
            }
        }
        .disabled(working)
        .overlay { if working { ProgressView() } }
    }

    private func secondary(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Theme.surfaceSunk, in: Capsule())
        }
    }

    private func picker(_ title: String, _ options: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
            Picker(title, selection: selection) {
                ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var toastView: some View {
        Group {
            if let toast {
                Text(toast).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.hud, in: Capsule()).padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Bindings / keys

    private var previewKey: String { "\(format.rawValue)-\(scale)-\(transparent)-\(model.canvas.watermark != nil)" }
    private var formatIndex: Binding<Int> {
        Binding(get: { ExportFormat.allCases.firstIndex(of: format) ?? 0 },
                set: { format = ExportFormat.allCases[$0]; if !format.supportsTransparency { transparent = false } })
    }
    private var scaleIndex: Binding<Int> {
        Binding(get: { Int(scale) - 1 }, set: { scale = CGFloat($0 + 1) })
    }
    private var watermarkBinding: Binding<Bool> {
        Binding(get: { model.canvas.watermark != nil },
                set: { on in model.edit { $0.watermark = on ? WatermarkSpec() : nil } })
    }

    // MARK: Actions

    private func rebuildPreview() {
        let ratio = model.canvas.aspect.ratio
        let h: CGFloat = 480
        preview = CanvasRenderer.shared.render(model.canvas, pixelSize: CGSize(width: h * ratio, height: h), quality: .preview, transparent: transparent)
    }

    private func fullImage() -> UIImage { Exporter.render(model.canvas, scale: scale, transparent: transparent) }

    private func saveToPhotos() async {
        working = true; defer { working = false }
        let image = fullImage()
        let png = transparent ? Exporter.data(image, format: .png, quality: 1) : nil
        let ok = await Exporter.saveToPhotos(image, pngData: png)
        flash(ok ? "Saved to Photos" : "Couldn't save")
    }

    private func shareExport() async {
        working = true; defer { working = false }
        guard let data = Exporter.data(fullImage(), format: format, quality: 0.95),
              let url = Exporter.writeTemp(data, ext: format.ext) else { flash("Export failed"); return }
        share = SharePayload(items: [url])
    }

    private func copyExport() async {
        working = true; defer { working = false }
        Exporter.copyToClipboard(fullImage()); flash("Copied")
    }

    private func shareCarousel() async {
        working = true; defer { working = false }
        let slices = Exporter.carouselSlices(fullImage(), count: carouselCount)
        let urls = slices.enumerated().compactMap { i, img -> URL? in
            img.pngData().flatMap { Exporter.writeTemp($0, ext: "png", name: "Boardly-\(i + 1)") }
        }
        guard !urls.isEmpty else { flash("Export failed"); return }
        share = SharePayload(items: urls)
    }

    private func exportAllPages() async {
        working = true; defer { working = false }
        var saved = 0
        for page in model.allPagesCommitted() {
            let px = CGSize(width: page.pixelSize.width * scale, height: page.pixelSize.height * scale)
            let image = CanvasRenderer.shared.render(page, pixelSize: px, quality: .export, transparent: transparent)
            if await Exporter.saveToPhotos(image, pngData: transparent ? image.pngData() : nil) { saved += 1 }
        }
        flash("Saved \(saved) pages to Photos")
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { toast = nil }
        }
    }
}

/// Checkerboard shown behind transparent previews.
private struct Checkerboard: View {
    var body: some View {
        GeometryReader { geo in
            let s: CGFloat = 12
            Path { p in
                let cols = Int(geo.size.width / s) + 1, rows = Int(geo.size.height / s) + 1
                for r in 0..<rows { for c in 0..<cols where (r + c) % 2 == 0 {
                    p.addRect(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)) } }
            }
            .fill(Color.gray.opacity(0.25))
        }
    }
}
