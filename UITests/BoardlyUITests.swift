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
        let photo = app.scrollViews.images.firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15), "Photo picker never showed a photo")
        photo.tap()

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
    }
}
