import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §2 — status, ring fraction, status line and "counts as met" for every goal type.
final class GoalProgressTests: XCTestCase {

    private let enUS = Locale(identifier: "en_US")

    private func progress(_ current: Double, _ goalType: GoalType, target: Double,
                          upper: Double? = nil, unit: String = "mg") -> GoalProgress {
        GoalProgress(current: current, goalType: goalType, target: target, upperBound: upper, unit: unit)
    }

    // MARK: - At least

    func testAtLeastBelowTargetIsInProgress() {
        let p = progress(2000, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(p.status, .inProgress)
        XCTAssertEqual(p.ringFraction, 0.5, accuracy: 1e-9)
        XCTAssertFalse(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "2,000 IU to go")
        XCTAssertEqual(p.progressText(locale: enUS), "2,000 of 4,000 IU")
    }

    func testAtLeastExactlyAtTargetIsMet() {
        let p = progress(4000, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(p.status, .met)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "Done")
    }

    func testAtLeastAboveTargetStaysMetWithFullRing() {
        let p = progress(6000, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(p.status, .met)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertTrue(p.countsAsMet)
    }

    func testAtLeastWithZeroTargetIsMet() {
        let p = progress(0, .minimum, target: 0)
        XCTAssertEqual(p.status, .met)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertTrue(p.countsAsMet)
    }

    // MARK: - At most

    func testAtMostBelowSeventyFivePercentIsInProgressAndMet() {
        let p = progress(200, .maximum, target: 400)
        XCTAssertEqual(p.status, .inProgress)
        XCTAssertEqual(p.ringFraction, 0.5, accuracy: 1e-9)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "200 mg left today")
    }

    func testAtMostAtExactlySeventyFivePercentIsNearingLimit() {
        let p = progress(300, .maximum, target: 400)
        XCTAssertEqual(p.status, .nearingLimit)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "100 mg left today")
    }

    func testAtMostJustBelowSeventyFivePercentIsInProgress() {
        XCTAssertEqual(progress(299, .maximum, target: 400).status, .inProgress)
    }

    func testAtMostAtEightyPercentMatchesMockup() {
        let p = progress(320, .maximum, target: 400)
        XCTAssertEqual(p.status, .nearingLimit)
        XCTAssertEqual(p.ringFraction, 0.8, accuracy: 1e-9)
        XCTAssertEqual(p.remainingText(locale: enUS), "80 mg left today")
    }

    func testAtMostExactlyAtLimitIsNearingAndStillMet() {
        let p = progress(400, .maximum, target: 400)
        XCTAssertEqual(p.status, .nearingLimit)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "Limit reached")
    }

    func testAtMostOverLimitIsOverWithFullRing() {
        let p = progress(450, .maximum, target: 400)
        XCTAssertEqual(p.status, .overLimit)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertFalse(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "50 mg over limit")
    }

    func testAtMostWithNothingLoggedIsInProgressAndMet() {
        let p = progress(0, .maximum, target: 400)
        XCTAssertEqual(p.status, .inProgress)
        XCTAssertEqual(p.ringFraction, 0)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "400 mg left today")
    }

    // MARK: - Between

    func testBetweenBelowLowerBoundIsInProgress() {
        let p = progress(92, .range, target: 120, upper: 160, unit: "g")
        XCTAssertEqual(p.status, .inProgress)
        XCTAssertEqual(p.ringFraction, 92.0 / 160.0, accuracy: 1e-9)
        XCTAssertFalse(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "28 g to range")
        XCTAssertEqual(p.progressText(locale: enUS), "92 of 120–160 g")
    }

    func testBetweenAtLowerBoundIsMet() {
        let p = progress(120, .range, target: 120, upper: 160, unit: "g")
        XCTAssertEqual(p.status, .met)
        XCTAssertTrue(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "In range")
    }

    func testBetweenAtUpperBoundIsMetWithFullRing() {
        let p = progress(160, .range, target: 120, upper: 160, unit: "g")
        XCTAssertEqual(p.status, .met)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertTrue(p.countsAsMet)
    }

    func testBetweenAboveUpperBoundIsOver() {
        let p = progress(170, .range, target: 120, upper: 160, unit: "g")
        XCTAssertEqual(p.status, .overLimit)
        XCTAssertEqual(p.ringFraction, 1)
        XCTAssertFalse(p.countsAsMet)
        XCTAssertEqual(p.remainingText(locale: enUS), "10 g over range")
    }

    func testRangeWithoutUpperBoundBehavesLikeAtLeast() {
        let below = progress(50, .range, target: 100, upper: nil, unit: "g")
        XCTAssertEqual(below.status, .inProgress)
        XCTAssertEqual(below.remainingText(locale: enUS), "50 g to go")

        let reached = progress(150, .range, target: 100, upper: nil, unit: "g")
        XCTAssertEqual(reached.status, .met)
        XCTAssertTrue(reached.countsAsMet)
        XCTAssertEqual(reached.remainingText(locale: enUS), "Done")
    }

    // MARK: - Edge cases

    func testNegativeTotalIsFlooredAtZero() {
        let p = progress(-500, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(p.current, 0)
        XCTAssertEqual(p.ringFraction, 0)
        XCTAssertEqual(p.remainingText(locale: enUS), "4,000 IU to go")
    }

    func testFloatDriftFromSummingStepsStillReachesTarget() {
        let total = 0.1 + 0.7  // 0.7999999999999999
        XCTAssertLessThan(total, 0.8)
        let p = progress(total, .minimum, target: 0.8, unit: "L")
        XCTAssertEqual(p.status, .met)
        XCTAssertTrue(p.countsAsMet)
    }

    func testFractionalAmountsShowUpToTwoDecimals() {
        let p = progress(0.75, .minimum, target: 2.5, unit: "L")
        XCTAssertEqual(p.remainingText(locale: enUS), "1.75 L to go")
        XCTAssertEqual(p.progressText(locale: enUS), "0.75 of 2.5 L")
    }

    func testEmptyUnitLeavesNoTrailingSpace() {
        let p = progress(5, .minimum, target: 8, unit: "")
        XCTAssertEqual(p.remainingText(locale: enUS), "3 to go")
        XCTAssertEqual(p.progressText(locale: enUS), "5 of 8")
    }

    func testNumbersFollowTheLocale() {
        let p = progress(2000, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(p.remainingText(locale: Locale(identifier: "de_DE")), "2.000 IU to go")
    }

    // MARK: - Value line

    func testValueLinePartsForEachGoalType() {
        let atLeast = progress(2000, .minimum, target: 4000, unit: "IU")
        XCTAssertEqual(atLeast.currentText(locale: enUS), "2,000")
        XCTAssertEqual(atLeast.goalText(locale: enUS), "/ 4,000 IU")

        let atMost = progress(320, .maximum, target: 400)
        XCTAssertEqual(atMost.currentText(locale: enUS), "320")
        XCTAssertEqual(atMost.goalText(locale: enUS), "max 400 mg")

        let between = progress(92, .range, target: 120, upper: 160, unit: "g")
        XCTAssertEqual(between.goalText(locale: enUS), "/ 120–160 g")
    }

    // MARK: - Log sheet

    func testGoalAmountTextForEachGoalType() {
        XCTAssertEqual(progress(0, .minimum, target: 4000, unit: "IU").goalAmountText(locale: enUS), "4,000 IU")
        XCTAssertEqual(progress(0, .maximum, target: 400).goalAmountText(locale: enUS), "400 mg")
        XCTAssertEqual(progress(0, .range, target: 120, upper: 160, unit: "g").goalAmountText(locale: enUS), "120–160 g")
    }

    func testAmountToGoalIsWhatsLeftOfAnAtLeastTarget() {
        XCTAssertEqual(progress(2000, .minimum, target: 4000).amountToGoal, 2000)
        XCTAssertNil(progress(4000, .minimum, target: 4000).amountToGoal)
    }

    func testAmountToGoalIsWhatsLeftToARangesLowerBound() {
        XCTAssertEqual(progress(92, .range, target: 120, upper: 160).amountToGoal, 28)
        XCTAssertNil(progress(130, .range, target: 120, upper: 160).amountToGoal)  // in range
        XCTAssertNil(progress(170, .range, target: 120, upper: 160).amountToGoal)  // over
    }

    func testAmountToGoalIsNilForAtMost() {
        XCTAssertNil(progress(0, .maximum, target: 400).amountToGoal)
    }

    func testFormattedAmountGroupsAndKeepsUpToTwoDecimals() {
        XCTAssertEqual(1000.0.formattedAmount(locale: enUS), "1,000")
        XCTAssertEqual(0.25.formattedAmount(locale: enUS), "0.25")
        XCTAssertEqual(1.5.formattedAmount(locale: Locale(identifier: "de_DE")), "1,5")
    }

    func testFormattedAmountKeepsExtraPrecisionWhenAskedFor() {
        // The log sheet edits and logs amounts at 6 decimals so a 0.125 step isn't rounded to 2.
        XCTAssertNotEqual(0.125.formattedAmount(locale: enUS), "0.125")
        XCTAssertEqual(0.125.formattedAmount(locale: enUS, maxFractionDigits: 6), "0.125")
        // The sheet formats and parses in the current locale, so the round trip must be lossless there.
        XCTAssertEqual(0.125.formattedAmount(maxFractionDigits: 6).parsedDouble, 0.125)
        XCTAssertEqual(1234.5.formattedAmount(maxFractionDigits: 6).parsedDouble, 1234.5)
    }

    // MARK: - Nutrient convenience

    func testNutrientInitializerReadsGoalFromTheModel() throws {
        let container = try ModelContainer.inMemoryForTests()
        let nutrient = Nutrient(name: "Protein", unit: "g", step: 20, dailyTarget: 120, sortOrder: 0,
                                goalType: .range, upperBound: 160)
        container.mainContext.insert(nutrient)

        XCTAssertEqual(GoalProgress(nutrient: nutrient, current: 130),
                       GoalProgress(current: 130, goalType: .range, target: 120, upperBound: 160, unit: "g"))
    }
}
