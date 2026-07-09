import CoreGraphics
import Foundation
import UIKit

/// Typed accessors/mutators the tool panels use to read and edit specific layer
/// content without repeating unwrap boilerplate.
extension EditorModel {

    // MARK: Screenshot (selected screenshot, else the primary one)

    var screenshotID: UUID? {
        if let s = selectedLayer, s.isScreenshot { return s.id }
        return project.canvas.primaryScreenshot?.id
    }

    var screenshotContent: ScreenshotContent? {
        guard let id = screenshotID, case .screenshot(let s)? = project.canvas[id]?.content else { return nil }
        return s
    }

    var screenshotTransform: LayerTransform? {
        guard let id = screenshotID else { return nil }
        return project.canvas[id]?.transform
    }

    /// Discrete screenshot edit (undo checkpoint) — for chips/toggles.
    func setScreenshot(_ mutate: (inout ScreenshotContent) -> Void) {
        guard let id = screenshotID else { return }
        edit { canvas in
            guard var layer = canvas[id], case .screenshot(var s) = layer.content else { return }
            mutate(&s); layer.content = .screenshot(s); canvas[id] = layer
        }
    }

    /// Live screenshot edit (no checkpoint) — for slider dragging.
    func updateScreenshotLive(_ mutate: (inout ScreenshotContent) -> Void) {
        guard let id = screenshotID else { return }
        guard var layer = project.canvas[id], case .screenshot(var s) = layer.content else { return }
        mutate(&s); layer.content = .screenshot(s); project.canvas[id] = layer
    }

    func updateScreenshotTransformLive(_ mutate: (inout LayerTransform) -> Void) {
        guard let id = screenshotID, var layer = project.canvas[id] else { return }
        mutate(&layer.transform); project.canvas[id] = layer
    }

    // MARK: Selected typed content

    var selectedText: TextContent? {
        if case .text(let t)? = selectedLayer?.content { return t }; return nil
    }
    var selectedAnnotation: AnnotationContent? {
        if case .annotation(let a)? = selectedLayer?.content { return a }; return nil
    }
    var selectedRedaction: RedactionContent? {
        if case .redaction(let r)? = selectedLayer?.content { return r }; return nil
    }
    var selectedSpotlight: SpotlightContent? {
        if case .spotlight(let s)? = selectedLayer?.content { return s }; return nil
    }

    func updateSelectedText(live: Bool = false, _ mutate: (inout TextContent) -> Void) {
        updateSelectedContent(live: live) { if case .text(var t) = $0 { mutate(&t); $0 = .text(t) } }
    }
    func updateSelectedAnnotation(live: Bool = false, _ mutate: (inout AnnotationContent) -> Void) {
        updateSelectedContent(live: live) { if case .annotation(var a) = $0 { mutate(&a); $0 = .annotation(a) } }
    }
    func updateSelectedRedaction(live: Bool = false, _ mutate: (inout RedactionContent) -> Void) {
        updateSelectedContent(live: live) { if case .redaction(var r) = $0 { mutate(&r); $0 = .redaction(r) } }
    }
    func updateSelectedSpotlight(live: Bool = false, _ mutate: (inout SpotlightContent) -> Void) {
        updateSelectedContent(live: live) { if case .spotlight(var s) = $0 { mutate(&s); $0 = .spotlight(s) } }
    }

    private func updateSelectedContent(live: Bool, _ mutate: (inout LayerContent) -> Void) {
        guard let id = selectedLayerID else { return }
        if live {
            guard var layer = project.canvas[id] else { return }
            mutate(&layer.content); project.canvas[id] = layer
        } else {
            edit { canvas in
                guard var layer = canvas[id] else { return }
                mutate(&layer.content); canvas[id] = layer
            }
        }
    }

    // MARK: promo templates

    var currentHeadlineString: String? {
        for layer in project.canvas.layers { if case .text(let t) = layer.content { return t.string } }
        return nil
    }

    /// Rebuild the current page from a template, keeping the screenshot + headline text.
    func applyTemplateToCurrentPage(_ template: PromoTemplate) {
        guard let imageID = screenshotContent?.imageID else { return }
        let headline = currentHeadlineString ?? template.starters[0]
        let canvas = template.buildPage(imageID: imageID, headline: headline)
        edit { $0 = canvas }
        selectedLayerID = canvas.primaryScreenshot?.id
    }

    /// Propagate the current page's background + device styling + headline style
    /// to every other page (each page keeps its own screenshot + headline text).
    func syncAllPages() {
        commitCurrentPage()
        guard var pages = project.pages, pages.count > 1 else { return }
        let ref = project.canvas
        let refScreenshot = ref.primaryScreenshot
        let refHeadline = ref.layers.first { if case .text = $0.content { return true }; return false }

        for i in pages.indices where i != pageIndex {
            pages[i].background = ref.background
            pages[i].aspect = ref.aspect
            pages[i].vignette = ref.vignette
            pages[i].grain = ref.grain
            pages[i].watermark = ref.watermark

            if case .screenshot(let rs)? = refScreenshot?.content, let refT = refScreenshot?.transform,
               let id = pages[i].primaryScreenshot?.id, var layer = pages[i][id], case .screenshot(var s) = layer.content {
                s.frame = rs.frame; s.shadow = rs.shadow; s.cornerRadius = rs.cornerRadius
                s.cleanStatusBar = rs.cleanStatusBar; s.clipShape = rs.clipShape; s.glass = rs.glass; s.reflection = rs.reflection
                layer.content = .screenshot(s)
                layer.transform.center = refT.center; layer.transform.size = refT.size
                layer.transform.rotationX = refT.rotationX; layer.transform.rotationY = refT.rotationY; layer.transform.rotation = refT.rotation
                pages[i][id] = layer
            }

            if case .text(let rt)? = refHeadline?.content, let refT = refHeadline?.transform,
               let idx = pages[i].layers.firstIndex(where: { if case .text = $0.content { return true }; return false }),
               case .text(var t) = pages[i].layers[idx].content {
                let keep = t.string
                t = rt; t.string = keep
                pages[i].layers[idx].content = .text(t)
                pages[i].layers[idx].transform = refT
            }
        }
        project.pages = pages
        project.modifiedAt = Date()
    }

    // MARK: Interaction convenience for sliders

    func slider(begin: Bool) { begin ? beginInteraction() : endInteraction() }

    /// The current screenshot bitmap, if available.
    var screenshotImage: UIImage? {
        guard case .screenshot(let s)? = (screenshotID.flatMap { project.canvas[$0]?.content }) else { return nil }
        return ImageStore.shared.image(for: s.imageID)
    }

    /// Replace the screenshot's bitmap by transforming it (crop/flip/rotate),
    /// pushing one undo checkpoint. The old bitmap stays in the store so undo works.
    func transformScreenshotImage(_ transform: (UIImage) -> UIImage) {
        guard let image = screenshotImage else { return }
        let newID = ImageStore.shared.save(transform(image))
        setScreenshot { $0.imageID = newID }
    }

    func editSelectedLayerVisibility(_ id: UUID) {
        edit { canvas in
            guard var layer = canvas[id] else { return }
            layer.isHidden.toggle()
            canvas[id] = layer
        }
    }
}
