import XCTest

/// The paywall's pinned button, plans and close button on the smallest iPhone and a usual one (#339). Its layout broke
/// three ways, each caught only by eye: the plans below the fold (#189, #205), Lifetime behind the footer and the ✕
/// scrolling away (#325). Run on "nutrx SE" and "nutrx iPhone 17" with the `nutrxUITests` scheme before a release
/// (CLAUDE.md, UI tests). The scheme's launch uses `StoreKit/nutrxPro.storekit`, so the plans load with their prices;
/// without it the paywall reads "Couldn't reach the App Store" and the tests skip. The paywall route opens the paywall
/// whatever the Pro state. It launches with `-screenshotDemoData`, which replaces the store, so only on a simulator
/// that's signed out of iCloud.
final class PaywallUITests: XCTestCase {
    private var app: XCUIApplication!

    /// The pinned purchase button: "Start free week" while the trial applies, "Subscribe", or "Buy lifetime".
    private var purchaseButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Start free week", "Subscribe", "Buy lifetime"]))
            .firstMatch
    }

    /// The line over the button naming the selected plan ("Yearly · $14.99 a year · 1 week free", its parts joined
    /// with no-break spaces around the dots).
    private var planLine: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Yearly", "·")).firstMatch
    }

    /// The Yearly and Lifetime cards: each one button, its label starting with the plan's name and holding its
    /// subtitle ("$1.17 a month, billed yearly", "Pay once, keep Pro forever").
    private var yearlyCard: XCUIElement { planCard("Yearly", detail: "billed yearly") }
    private var lifetimeCard: XCUIElement { planCard("Lifetime", detail: "Pay once") }

    private func planCard(_ name: String, detail: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS[c] %@", name, detail)).firstMatch
    }

    private var window: CGRect { app.windows.firstMatch.frame }

    /// The paywall's own scroll view, the one holding its links: Today's, under the sheet, are scroll views too.
    private var sheet: XCUIElement {
        app.scrollViews.containing(.button, identifier: "Privacy").firstMatch
    }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launchOnThePaywall() throws {
        app = XCUIApplication()
        app.launchArguments = ["-screenshotDemoData", "-screenshotRoute", "paywall"]
        app.launch()
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 15), "The paywall didn't open")
        // The plans, once the store answers. Only an unreachable store skips: anything else missing (a changed label)
        // fails, so the tests can't quietly stop testing.
        if !yearlyCard.waitForExistence(timeout: 15), app.staticTexts["Couldn't reach the App Store"].exists {
            throw XCTSkip("The plans didn't load: is StoreKit/nutrxPro.storekit in the nutrxUITests scheme's launch?")
        }
        XCTAssertTrue(yearlyCard.exists, "No Yearly card on the paywall: did its label change?")
        XCTAssertTrue(purchaseButton.exists, "No purchase button on the paywall: did its label change?")
    }

    /// In view the way the app judges it (`PlanLine.shows`): the card's middle below the sheet's top and more than
    /// `PlanLine.margin` (10 pt) above the pinned button's top.
    private func isInView(_ card: XCUIElement) -> Bool {
        let middle = card.frame.midY
        return middle > sheet.frame.minY && middle < purchaseButton.frame.minY - 10
    }

    /// The plan line follows the card: absent while it's in view, above the button while it isn't. The line fades, so
    /// both wait a moment.
    private func assertThePlanLineFollows(_ card: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        if isInView(card) {
            let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: planLine)
            XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 2), .completed,
                           "The plan line shows while the Yearly card is in view", file: file, line: line)
        } else {
            XCTAssertTrue(planLine.waitForExistence(timeout: 2), "No plan line with the Yearly card out of view",
                          file: file, line: line)
            assertAboveTheButton(planLine, "The plan line", file: file, line: line)
        }
    }

    /// Wholly inside the window and above the pinned button: `isHittable` only looks at the centre.
    private func assertAboveTheButton(_ element: XCUIElement, _ name: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.isHittable, "\(name) isn't tappable", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minY, window.minY, "\(name) runs off the top", file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxY, purchaseButton.frame.minY + 1, "\(name) is behind the button",
                                 file: file, line: line)
    }

    /// A slow drag up the sheet, a step at a time, until `element` is clear of the pinned button (a swipe's momentum
    /// overshoots).
    private func scroll(until element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists, element.isHittable, element.frame.maxY <= purchaseButton.frame.minY {
                return
            }
            sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
    }

    /// As it opens: the purchase button wholly on screen, and the selected plan in view, as its card or the line over
    /// the button (#338: the line shows only while the card is out of view).
    func testTheButtonAndTheSelectedPlanAreOnScreen() throws {
        try launchOnThePaywall()
        let button = purchaseButton
        XCTAssertTrue(button.isHittable, "The purchase button isn't tappable")
        XCTAssertLessThanOrEqual(button.frame.maxY, window.maxY, "The purchase button is cut off at the bottom")

        assertThePlanLineFollows(yearlyCard)
    }

    /// Scrolled to the end: the ✕ still at the top (#325), and Lifetime and Restore · Terms · Privacy above the
    /// pinned button, not behind it.
    func testLifetimeTheLinksAndCloseAreReachable() throws {
        try launchOnThePaywall()
        let privacy = app.buttons["Privacy"].firstMatch
        scroll(until: privacy)

        assertAboveTheButton(privacy, "Privacy")
        assertAboveTheButton(app.buttons["Terms"].firstMatch, "Terms")
        assertAboveTheButton(app.buttons["Restore purchases"].firstMatch, "Restore purchases")

        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.isHittable, "Close scrolled away")
        XCTAssertLessThan(close.frame.midY, window.midY, "Close isn't at the top")

        let lifetime = lifetimeCard
        scroll(until: lifetime)
        assertAboveTheButton(lifetime, "Lifetime")
    }

    /// The plan line shows once the selected plan's card has scrolled away above, and names that plan (#338).
    func testThePlanLineShowsOnceTheCardScrollsAway() throws {
        try launchOnThePaywall()
        scroll(until: app.buttons["Privacy"].firstMatch)
        // On a screen tall enough that the whole sheet fits, the card never leaves, and the line stays away.
        assertThePlanLineFollows(yearlyCard)
    }
}
