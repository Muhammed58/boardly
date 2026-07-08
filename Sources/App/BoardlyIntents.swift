import AppIntents
import UIKit

/// Siri / Shortcuts action: grab the most recent screenshot, beautify it with a
/// default style, and save it to Photos — no app launch required.
struct BeautifyLatestScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Beautify Latest Screenshot"
    static var description = IntentDescription("Adds a beautiful background to your most recent screenshot and saves it to Photos.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let image = await PhotoLibrary.latestScreenshot(promptIfNeeded: true) else {
            return .result(dialog: "I couldn't find a screenshot in your library.")
        }
        let normalized = image.normalizedUp()
        let id = ImageStore.shared.save(normalized)
        let base = EditorCanvas.beautified(imageID: id, imageSize: normalized.size)
        let styled = StyleCatalog.all[1].look.previewCanvas(base: base) // "Violet"
        let output = CanvasRenderer.shared.render(styled, pixelSize: styled.pixelSize, quality: .export)
        let saved = await Exporter.saveToPhotos(output, pngData: nil)
        return .result(dialog: saved ? "Saved a beautified screenshot to your Photos." : "I couldn't save to Photos.")
    }
}

struct BoardlyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BeautifyLatestScreenshotIntent(),
            phrases: [
                "Beautify my latest screenshot in \(.applicationName)",
                "Beautify my screenshot with \(.applicationName)",
            ],
            shortTitle: "Beautify Screenshot",
            systemImageName: "wand.and.stars"
        )
    }
}
