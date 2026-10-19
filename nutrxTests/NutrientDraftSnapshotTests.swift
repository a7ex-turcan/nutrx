import SwiftData
import XCTest
@testable import nutrx

/// The nutrient form asks before throwing away changes (#74): its draft's snapshot tells "untouched" from "edited".
final class NutrientDraftSnapshotTests: XCTestCase {
    func testAnUntouchedEditFormHasNoChanges() throws {
        let container = try ModelContainer.inMemoryForTests()
        let nutrient = Nutrient(name: "Iron", unit: "mg", step: 9, dailyTarget: 18, sortOrder: 0)
        container.mainContext.insert(nutrient)
        let draft = NutrientDraft()
        draft.populate(from: nutrient)
        let opened = draft.snapshot

        let again = NutrientDraft()
        again.populate(from: nutrient)
        XCTAssertEqual(again.snapshot, opened, "the same nutrient fills the same form")
    }

    func testAnyEditCounts() {
        let draft = NutrientDraft()
        let opened = draft.snapshot
        let edits: [(NutrientDraft) -> Void] = [
            { $0.name = "Iron" }, { $0.unit = "mg" }, { $0.dailyTarget = "18" }, { $0.step = "9" },
            { $0.notes = "with food" }, { $0.goalType = .range }, { $0.tint = .coral }, { $0.symbolName = "drop" },
            { $0.pendingReminderTimes = [Date(timeIntervalSince1970: 0)] }, { $0.endDate = Date(timeIntervalSince1970: 0) },
            { $0.upperBound = "40" }, { $0.supplyServings = "120" }, { $0.pendingStacks = [.new("Morning")] },
        ]
        for edit in edits {
            let edited = NutrientDraft()
            edit(edited)
            XCTAssertNotEqual(edited.snapshot, opened)
        }
    }

    func testTypingAndUndoingIsNoChange() {
        let draft = NutrientDraft()
        let opened = draft.snapshot
        draft.name = "Zinc"
        draft.name = ""
        XCTAssertEqual(draft.snapshot, opened)
    }
}
