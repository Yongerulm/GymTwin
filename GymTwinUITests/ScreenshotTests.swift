import XCTest

/// Drives the app through its main screens and attaches a screenshot of each,
/// so the dark redesign can be reviewed. Navigation is guarded with existence
/// checks so a missing element never hard-fails the capture run.
@MainActor
final class ScreenshotTests: XCTestCase {

    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uitest-no-health"]
        app.launch()
    }

    func testCaptureMainScreens() {
        // 1. Today (launch screen)
        snap("01-Today")

        // 2. Gym tab
        tapTab("Gym")
        snap("02-Gym")

        // 3. First area card → Machine grid
        let areaCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", " area,")).firstMatch
        if areaCard.waitForExistence(timeout: 5) {
            areaCard.tap()
            snap("03-MachineGrid")

            // 4. First machine → detail
            let firstMachine = app.scrollViews.buttons.firstMatch
            if firstMachine.waitForExistence(timeout: 5) {
                firstMachine.tap()
                snap("04-MachineDetail")
            }
        }

        // 5. Progress tab
        tapTab("Progress")
        snap("05-Progress")

        // 6. Settings tab
        tapTab("Settings")
        snap("06-Settings")

        // 7. Workout flow (modal, captured last so it can't block tab capture)
        tapTab("Today")
        let start = app.buttons["Start workout"].firstMatch
        if start.waitForExistence(timeout: 5) {
            start.tap()
            snap("07-Workout")
            dismissModal()
        }

        // 8. Scan flow (modal)
        tapTab("Today")
        let scan = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Scan")).firstMatch
        if scan.waitForExistence(timeout: 5) {
            scan.tap()
            snap("08-Scan")
            dismissModal()
        }
    }

    // MARK: - Helpers

    private func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 5) { tab.tap() }
    }

    private func dismissModal() {
        for label in ["Cancel", "Close", "Done"] {
            let b = app.buttons[label]
            if b.exists { b.tap(); return }
        }
        // Fall back to a swipe-down dismiss for sheets.
        app.swipeDown(velocity: .fast)
    }

    private func snap(_ name: String) {
        // Small settle delay so animations finish before the capture.
        _ = app.wait(for: .runningForeground, timeout: 2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
