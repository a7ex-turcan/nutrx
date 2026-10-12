import XCTest
@testable import nutrx

/// DESIGN.md §5.8 — onboarding's starting points are valid, editable pre-fills.
final class StartingPointTests: XCTestCase {

    func testTheDesignTable() {
        XCTAssertEqual(StartingPoint.all.map(\.name), ["Vitamin D", "Magnesium", "Omega-3", "Water", "Protein", "Creatine"])
        let protein = StartingPoint.all[4]
        XCTAssertEqual(protein.goalType, .range)
        XCTAssertEqual(protein.target, 120)
        XCTAssertEqual(protein.upperBound, 160)
        XCTAssertEqual(StartingPoint.all[3].step, 0.25)
    }

    func testEveryStartingPointMakesAValidDraft() {
        for point in StartingPoint.all {
            let draft = NutrientDraft()
            point.fill(draft)
            XCTAssertTrue(draft.isValid, point.name)
            XCTAssertEqual(draft.name, point.name)
            XCTAssertEqual(draft.unit, point.unit)
            XCTAssertEqual(draft.goalType, point.goalType)
            XCTAssertEqual(draft.dailyTarget.parsedDouble, point.target, point.name)
            XCTAssertEqual(draft.step.parsedDouble, point.step, point.name)
            XCTAssertEqual(draft.tint, point.tint)
            XCTAssertEqual(draft.symbolName, point.symbolName)
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
        draft.notes = "post-workout"
        StartingPoint.all[0].fill(draft)  // Vitamin D
        XCTAssertEqual(draft.goalType, .minimum)
        XCTAssertEqual(draft.upperBound, "")
        XCTAssertEqual(draft.notes, "")
    }

    func testSubtitle() {
        XCTAssertEqual(StartingPoint.all[0].subtitle, "IU · at least")
        XCTAssertEqual(StartingPoint.all[4].subtitle, "g · between")
    }
}
