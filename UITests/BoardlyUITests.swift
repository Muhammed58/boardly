import XCTest

/// Drives the real import flow (New Screenshot → photo picker → editor) and
/// verifies the editor respects the safe areas afterwards.
final class BoardlyUITests: XCTestCase {

    @MainActor
    func testEditorRespectsSafeAreasAfterPickerImport() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["New Screenshot"].tap()

        // The photo grid lives in the out-of-process picker; give it time.
        // Grid cells are labeled "Photo, <date>…" — this skips the app's own
        // images behind the sheet and the icon of the "Private Access to
        // Photos" education banner the picker sometimes shows.
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15), "Photo picker never showed a photo cell")
        // Element tap() refuses picker cells (they report non-hittable from the
        // remote process); a coordinate tap does not check hittability.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let back = app.buttons["editor.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 20), "Editor did not open after picking a photo")
        sleep(2) // let any presentation animation settle

        let backY = back.frame.minY
        let toolBar = app.buttons["tool.styles"]
        XCTAssertTrue(toolBar.exists, "Tool bar missing")
        let toolMaxY = toolBar.frame.maxY
        let screenMaxY = app.frame.maxY

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "editor-after-picker"
        shot.lifetime = .keepAlways
        add(shot)

        // On notch/island devices the top bar must clear the status area and the
        // tool bar must sit above the home indicator.
        XCTAssertGreaterThan(backY, 40, "Top bar is behind the status bar (back button minY=\(backY))")
        XCTAssertLessThan(toolMaxY, screenMaxY - 20, "Tool bar is flush with the screen bottom (maxY=\(toolMaxY), screen=\(screenMaxY))")

        // Save the project and verify the Recent tile stays inside the screen
        // margins (wide thumbnails used to stretch tiles past the left edge).
        back.tap()
        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 10), "Home did not return after saving")
        sleep(1) // let the cover dismissal animation settle
        let title = app.staticTexts["Screenshot"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Saved project tile did not appear on Home")
        let homeShot = XCTAttachment(screenshot: app.screenshot())
        homeShot.name = "home-after-save"
        homeShot.lifetime = .keepAlways
        add(homeShot)
        XCTAssertGreaterThan(title.frame.minX, 8, "Recent tile overflows the left screen edge (title minX=\(title.frame.minX))")
    }
}
