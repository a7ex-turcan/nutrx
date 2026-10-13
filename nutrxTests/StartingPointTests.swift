import XCTest
@testable import nutrx

/// DESIGN.md §5.8 — onboarding's starting points are editable pre-fills with no suggested amounts.
final class StartingPointTests: XCTestCase {

    func testTheDesignTable() {
        XCTAssertEqual(StartingPoint.all.map(\.name), ["Vitamin D", "Magnesium", "Omega-3", "Water", "Protein", "Creatine"])
        XCTAssertEqual(StartingPoint.all[4].goalType, .range)  // Protein
        XCTAssertEqual(StartingPoint.all[3].unit, "L")  // Water
    }

    func testFillingSetsTheNameUnitAndLookButNoAmounts() {
        for point in StartingPoint.all {
            let draft = NutrientDraft()
            point.fill(draft)
            XCTAssertEqual(draft.name, point.name)
            XCTAssertEqual(draft.unit, point.unit)
            XCTAssertEqual(draft.goalType, point.goalType)
            XCTAssertEqual(draft.tint, point.tint)
            XCTAssertEqual(draft.symbolName, point.symbolName)
            // nutrx doesn't recommend intakes: the user types the goal and step.
            XCTAssertEqual(draft.dailyTarget, "", point.name)
            XCTAssertEqual(draft.upperBound, "", point.name)
            XCTAssertEqual(draft.step, "", point.name)
            XCTAssertFalse(draft.isValid, point.name)
        }
    }

    func testEveryStartingPointIsValidOnceTheAmountsAreEntered() {
        for point in StartingPoint.all {
            let draft = NutrientDraft()
            point.fill(draft)
            draft.dailyTarget = "10"
            if point.goalType == .range { draft.upperBound = "20" }
            draft.step = "5"
            XCTAssertTrue(draft.isValid, point.name)
        }
    }

    func testSymbolsComeFromThePickerSet() {
        for point in StartingPoint.all {
            XCTAssertTrue(SymbolPicker.choices.map(\.symbol).contains(point.symbolName), point.name)
        }
    }

    func testTintsAreAllDifferent() {
        XCTAssertEqual(Set(StartingPoint.all.map(\.tint)).count, StartingPoint.all.count)
    }

    func testFillingReplacesWhatWasThere() {
        let draft = NutrientDraft()
        StartingPoint.all[4].fill(draft)  // Protein, a range
        draft.dailyTarget = "120"
        draft.upperBound = "160"
        draft.step = "20"
        draft.notes = "post-workout"
        StartingPoint.all[0].fill(draft)  // Vitamin D
        XCTAssertEqual(draft.goalType, .minimum)
        XCTAssertEqual(draft.dailyTarget, "")
        XCTAssertEqual(draft.upperBound, "")
        XCTAssertEqual(draft.step, "")
        XCTAssertEqual(draft.notes, "")
    }

    func testSubtitle() {
        XCTAssertEqual(StartingPoint.all[0].subtitle, "IU · at least")
        XCTAssertEqual(StartingPoint.all[4].subtitle, "g · between")
    }
}
