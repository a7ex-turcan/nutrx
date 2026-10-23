import XCTest
@testable import nutrx

/// The paywall's and Pro screens' words: buttons, price terms, plan rows, status lines.
final class ProTextTests: XCTestCase {
    private let enUS = Locale(identifier: "en_US")
    private let renews = Date(timeIntervalSince1970: 1_823_501_100)  // 2027-10-14 08:05 UTC

    func testPrimaryButton() {
        XCTAssertEqual(ProText.primaryTitle(plan: .yearly, trialEligible: true), "Start free week")
        XCTAssertEqual(ProText.primaryTitle(plan: .yearly, trialEligible: false), "Subscribe")
        XCTAssertEqual(ProText.primaryTitle(plan: .monthly, trialEligible: true), "Subscribe")
        XCTAssertEqual(ProText.primaryTitle(plan: .lifetime, trialEligible: true), "Buy lifetime")
    }

    func testPlanSummaryNamesThePlanAndPrice() {
        func summary(_ plan: ProAccess.Plan, _ price: String, trial: Bool = true) -> String {
            ProText.planSummary(plan: plan, price: price, trialEligible: trial)
                .replacingOccurrences(of: "\u{00A0}", with: " ")
        }
        XCTAssertEqual(summary(.yearly, "$14.99"), "Yearly · $14.99 a year · 1 week free")
        XCTAssertEqual(summary(.yearly, "$14.99", trial: false), "Yearly · $14.99 a year")
        XCTAssertEqual(summary(.monthly, "$1.99"), "Monthly · $1.99 a month")
        XCTAssertEqual(summary(.lifetime, "$29.99"), "Lifetime · $29.99 once")
    }

    /// A line breaks only at a dot, never inside "1 week free" or "14,99 € a year".
    func testPlanSummaryBreaksOnlyBetweenParts() {
        let text = ProText.planSummary(plan: .yearly, price: "14,99 €", trialEligible: true)
        XCTAssertEqual(text.components(separatedBy: " · ").count, 3)
        XCTAssertFalse(text.replacingOccurrences(of: " · ", with: "").contains(" "))
    }

    func testTermsSayWhatsChargedAndHowToCancel() {
        XCTAssertEqual(ProText.terms(plan: .yearly, price: "$14.99", trialEligible: true),
                       "1 week free, then $14.99 a year. Cancel anytime in Settings.")
        XCTAssertEqual(ProText.terms(plan: .yearly, price: "$14.99", trialEligible: false),
                       "$14.99 a year. Cancel anytime in Settings.")
        XCTAssertEqual(ProText.terms(plan: .monthly, price: "$1.99", trialEligible: false),
                       "$1.99 a month. Cancel anytime in Settings.")
        XCTAssertEqual(ProText.terms(plan: .lifetime, price: "$29.99", trialEligible: false),
                       "One payment of $29.99. No subscription.")
    }

    func testPlanRows() {
        XCTAssertEqual(ProText.planSubtitle(.yearly, monthlyEquivalent: "$1.25"), "$1.25 a month, billed yearly")
        XCTAssertEqual(ProText.planSubtitle(.monthly, monthlyEquivalent: nil), "Billed monthly")
        XCTAssertEqual(ProText.planSubtitle(.lifetime, monthlyEquivalent: nil), "Pay once, keep Pro forever")
    }

    func testMonthlyEquivalentRoundsToCents() {
        let usd = Decimal.FormatStyle.Currency(code: "USD", locale: enUS)
        XCTAssertEqual(ProText.monthlyEquivalent(ofYearly: Decimal(string: "14.99")!, format: usd), "$1.25")
        let eur = Decimal.FormatStyle.Currency(code: "EUR", locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(ProText.monthlyEquivalent(ofYearly: Decimal(string: "17.99")!, format: eur), "1,50\u{00A0}€")  // a no-break space before €
    }

    func testStatusLines() {
        let renewing = ProAccess.Entitlement(plan: .yearly, expirationDate: renews, isFamilyShared: false, willAutoRenew: true)
        XCTAssertEqual(ProText.shortStatus(renewing, locale: enUS), "Yearly · renews Oct 14, 2027")
        XCTAssertEqual(ProText.longStatus(renewing, locale: enUS), "Yearly plan · renews October 14, 2027")

        let cancelled = ProAccess.Entitlement(plan: .monthly, expirationDate: renews, isFamilyShared: false, willAutoRenew: false)
        XCTAssertEqual(ProText.shortStatus(cancelled, locale: enUS), "Monthly · ends Oct 14, 2027")

        let trial = ProAccess.Entitlement(plan: .yearly, expirationDate: renews, isFamilyShared: false,
                                          isTrial: true, willAutoRenew: true)
        XCTAssertEqual(ProText.shortStatus(trial, locale: enUS), "Yearly · free until Oct 14, 2027")

        let lifetime = ProAccess.Entitlement(plan: .lifetime, expirationDate: nil, isFamilyShared: false)
        XCTAssertEqual(ProText.shortStatus(lifetime, locale: enUS), "Lifetime")
        XCTAssertEqual(ProText.longStatus(lifetime, locale: enUS), "Lifetime · yours for good")
    }

    func testReleaseListsOnlyShippedFeatures() {
        XCTAssertEqual(ProFeature.listed(shipped: [], debug: false), [])
        XCTAssertEqual(ProFeature.listed(shipped: [.supply], debug: false), [.supply])
    }

    func testDebugListsEveryFeatureUntilOneShips() {
        XCTAssertEqual(ProFeature.listed(shipped: [], debug: true), ProFeature.allCases)
        XCTAssertEqual(ProFeature.listed(shipped: [.supply], debug: true), [.supply])
    }

    func testTaglineOnlyNamesShippedFeatures() {
        XCTAssertEqual(ProText.tagline([.supply]), "Know when a bottle runs out")
        XCTAssertEqual(ProText.tagline([.supply, .scan]), "Supply and label scan")
        XCTAssertEqual(ProText.tagline([.supply, .scan, .recap]), "Supply, label scan and recaps",
                       "three shipped: no \"and more\"")
        XCTAssertEqual(ProText.tagline(ProFeature.allCases), "Supply, label scan, recaps and more")
    }

    func testAppleIntelligenceNoteNamesOnlyListedFeaturesItImproves() {
        XCTAssertNil(ProText.appleIntelligenceNote([.supply], device: "iPhone"))
        XCTAssertEqual(ProText.appleIntelligenceNote([.supply, .scan], device: "iPhone"),
                       "Apple Intelligence makes label scanning richer. Every Pro feature still works on this iPhone.")
        XCTAssertEqual(ProText.appleIntelligenceNote(ProFeature.allCases, device: "iPad"),
                       "Apple Intelligence makes label scanning and recaps richer. Every Pro feature still works on this iPad.")
    }

    func testShippedFeatures() {
        XCTAssertEqual(ProFeature.allCases.filter(\.isShipped), ProFeature.allCases)
        XCTAssertEqual(ProText.tagline(ProFeature.allCases.filter(\.isShipped)), "Supply, label scan, recaps and more")
    }

    func testAppleIntelligenceRowNotes() {
        XCTAssertEqual(ProText.appleIntelligenceRowNote(.recap, reading: .basic, device: "iPhone"),
                       "Simpler wording on this iPhone")
        XCTAssertEqual(ProText.appleIntelligenceRowNote(.scan, reading: .modelTurnedOff, device: "iPad"),
                       "Basic text reading on this iPad")
        XCTAssertNil(ProText.appleIntelligenceRowNote(.recap, reading: .model, device: "iPhone"))
        XCTAssertNil(ProText.appleIntelligenceRowNote(.supply, reading: .basic, device: "iPhone"))
    }

    /// Courses (#99) is Pro, so the paywall, the Pro screen and "Enjoy nutrx Pro" list it (#147).
    func testCoursesIsListed() {
        XCTAssertTrue(ProFeature.listed.contains(.courses))
        XCTAssertEqual(ProFeature.courses.title, "Courses")
        XCTAssertNil(ProFeature.courses.appleIntelligenceName, "courses don't use the on-device model")
    }

    /// Schedules (#132) ship in 2.4, last in the list.
    func testSchedulesIsListed() {
        XCTAssertTrue(ProFeature.listed.contains(.schedules))
        XCTAssertEqual(ProFeature.allCases.last, .schedules)
        XCTAssertEqual(ProFeature.schedules.title, "Schedules")
        XCTAssertEqual(ProFeature.schedules.subtitle, "Take something on set days")
        XCTAssertNil(ProFeature.schedules.appleIntelligenceName, "schedules don't use the on-device model")
    }

    func testPrimaryButtonIsLabelledWhilePurchasing() {
        XCTAssertEqual(ProText.primaryAccessibilityLabel(plan: .yearly, trialEligible: true, purchasing: false),
                       "Start free week")
        XCTAssertEqual(ProText.primaryAccessibilityLabel(plan: .lifetime, trialEligible: false, purchasing: false),
                       "Buy lifetime")
        XCTAssertEqual(ProText.primaryAccessibilityLabel(plan: .monthly, trialEligible: false, purchasing: true),
                       "Purchasing…", "the spinner alone read as nothing (#94)")
    }

    func testWelcomeNamesWhatsOn() {
        XCTAssertEqual(ProText.welcome([.supply]), "Supply is on. Nothing you already use has changed.")
        XCTAssertEqual(ProText.welcome([.supply, .scan]),
                       "Supply and label scanning are on. Nothing you already use has changed.")
        XCTAssertEqual(ProText.welcome(ProFeature.allCases),
                       "Supply, label scanning, weekly recaps, Apple Health trends, doctor reports, courses and schedules are on. Nothing you already use has changed.")
    }

    func testPlanChip() {
        XCTAssertEqual(ProText.planChipTitle(isPro: true), "PRO")
        XCTAssertEqual(ProText.planChipTitle(isPro: false), "Free")
        XCTAssertEqual(ProText.planChipAccessibilityLabel(isPro: true), "nutrx Pro, active")
        XCTAssertEqual(ProText.planChipAccessibilityLabel(isPro: false), "Free plan. See what nutrx Pro adds")
    }
}
