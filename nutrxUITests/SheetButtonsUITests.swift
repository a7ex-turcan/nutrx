import XCTest

/// The sheets' Log buttons at half height on the smallest iPhone (#222). The log sheet's half height cut its Log
/// button off on the iPhone SE and the folded iPhone Duo (#212), and the stack sheet's rows once pushed its footer
/// down (#180, #213): both were only caught by eye. Run on "nutrx SE" with the `nutrxUITests` scheme before a release
/// (CLAUDE.md, UI tests). It launches with `-screenshotDemoData`, which replaces the store, so only on a simulator
/// that's signed out of iCloud.
final class SheetButtonsUITests: XCTestCase {
    /// The sheet's own Log button: "Log 1,000 IU" or "Log 3 nutrients" (after the plus symbol's "Add"), never Today's
    /// "Log Morning" behind the sheet.
    private let sheetLogButton = NSPredicate(format: "label MATCHES %@", ".*Log [0-9].*")

    private func launchOnToday() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotDemoData", "-screenshotRoute", "today"]
        app.launch()
        return app
    }

    /// A nutrient card opens the log sheet at half height, with Log on screen and tappable without dragging the
    /// sheet up.
    func testLogSheetsLogButtonIsTappableAtHalfHeight() {
        let app = launchOnToday()
        // Below the fold on the SE, and Today's list only builds the rows near the screen: scroll until it's there.
        // A slow drag a third of the list at a time, not a swipe: a swipe's momentum carried it past (the card
        // isn't a button to the tests, so it's matched by its label whatever its type).
        let card = app.descendants(matching: .any)["Vitamin D"].firstMatch
        XCTAssertTrue(app.buttons["Log Morning"].firstMatch.waitForExistence(timeout: 15), "Today didn't load")
        let list = app.collectionViews.firstMatch
        for _ in 0..<6 where !card.isHittable {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(card.isHittable, "No Vitamin D card on Today")
        card.tap()

        let log = app.buttons.matching(sheetLogButton).firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 5), "The log sheet didn't open")
        XCTAssertTrue(log.isHittable, "The log sheet's Log button isn't tappable at half height")
    }

    /// A stack's Log opens its sheet, with the pinned Log button tappable at the height it opens at.
    func testStackSheetsLogButtonIsTappableWhenItOpens() {
        let app = launchOnToday()
        let logStack = app.buttons["Log Morning"].firstMatch
        XCTAssertTrue(logStack.waitForExistence(timeout: 15), "No Morning stack on Today")
        logStack.tap()

        let log = app.buttons.matching(sheetLogButton).firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 5), "The stack sheet didn't open")
        XCTAssertTrue(log.isHittable, "The stack sheet's Log button isn't tappable when it opens")
    }
}
