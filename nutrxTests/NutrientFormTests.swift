import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §5.6–5.7 — the nutrient form's draft, the suggested tint and group creation.
final class NutrientFormTests: XCTestCase {

    private lazy var container: ModelContainer = try! ModelContainer.inMemoryForTests()
    private var context: ModelContext { container.mainContext }

    // MARK: - Suggested tint

    func testSuggestedTintIsFirstUnusedInPinnedOrder() {
        XCTAssertEqual(NutrientTint.suggested(avoiding: []), .green)
        XCTAssertEqual(NutrientTint.suggested(avoiding: [.green, .blue]), .teal)
    }

    func testSuggestedTintIsLeastUsedOnceAllAreTaken() {
        var used = NutrientTint.allCases
        used.append(contentsOf: [.green, .teal])  // green and teal used twice
        XCTAssertEqual(NutrientTint.suggested(avoiding: used), .blue)
    }

    // MARK: - Draft round trip

    private func makeNutrient() -> Nutrient {
        let nutrient = Nutrient(name: "Protein", unit: "g", step: 20, dailyTarget: 120, sortOrder: 0,
                                goalType: .range, upperBound: 160)
        nutrient.tint = .coral
        nutrient.symbolName = "dumbbell"
        nutrient.notes = "Post-workout"
        context.insert(nutrient)
        return nutrient
    }

    func testPopulateCopiesEveryField() {
        let draft = NutrientDraft()
        draft.populate(from: makeNutrient())

        XCTAssertEqual(draft.name, "Protein")
        XCTAssertEqual(draft.unit, "g")
        XCTAssertEqual(draft.step.parsedDouble, 20)
        XCTAssertEqual(draft.dailyTarget.parsedDouble, 120)
        XCTAssertEqual(draft.upperBound.parsedDouble, 160)
        XCTAssertEqual(draft.goalType, .range)
        XCTAssertEqual(draft.tint, .coral)
        XCTAssertEqual(draft.symbolName, "dumbbell")
        XCTAssertEqual(draft.notes, "Post-workout")
    }

    func testPopulateShowsNumbersTheWayTheyAreTyped() {
        // Not "20.0", and in the current locale so parsedDouble reads them back.
        XCTAssertEqual(NutrientDraft.editableText(20), "20")
        XCTAssertEqual(NutrientDraft.editableText(0.25).parsedDouble, 0.25)
        XCTAssertEqual(NutrientDraft.editableText(4000).parsedDouble, 4000)
    }

    func testApplyWritesTheEditedLookAndGoal() {
        let nutrient = makeNutrient()
        let draft = NutrientDraft()
        draft.populate(from: nutrient)
        draft.tint = .indigo
        draft.symbolName = "moon"
        draft.goalType = .maximum
        draft.dailyTarget = NutrientDraft.editableText(400)
        draft.notes = "  "

        draft.apply(to: nutrient)

        XCTAssertEqual(nutrient.tint, .indigo)
        XCTAssertEqual(nutrient.symbolName, "moon")
        XCTAssertEqual(nutrient.goalType, .maximum)
        XCTAssertEqual(nutrient.dailyTarget, 400)
        XCTAssertNil(nutrient.upperBound, "only ranges keep an upper bound")
        XCTAssertNil(nutrient.notes, "blank notes are cleared")
    }

    func testInsertCreatesNutrientWithLookInGroup() throws {
        let group = NutrientGroup(name: "Morning stack", sortOrder: 0)
        context.insert(group)
        let draft = NutrientDraft()
        draft.name = "Creatine"
        draft.unit = "g"
        draft.step = "5"
        draft.dailyTarget = "5"
        draft.tint = .teal
        draft.symbolName = "waterbottle"

        let nutrient = try XCTUnwrap(draft.insertNutrient(into: context, group: group, sortOrder: 3))

        XCTAssertEqual(nutrient.tintRaw, "teal")
        XCTAssertEqual(nutrient.symbolName, "waterbottle")
        XCTAssertEqual(nutrient.group, group)
        XCTAssertEqual(nutrient.sortOrder, 3)
    }

    func testResetRestoresDefaults() {
        let draft = NutrientDraft()
        draft.tint = .pink
        draft.symbolName = "heart"
        draft.reset()
        XCTAssertEqual(draft.tint, .green)
        XCTAssertEqual(draft.symbolName, "pills")
    }

    // MARK: - Groups

    func testNewGroupGoesAfterUserGroupsBeforeGeneral() throws {
        let general = NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true)
        let morning = NutrientGroup(name: "Morning", sortOrder: 0)
        let evening = NutrientGroup(name: "Evening", sortOrder: 4)
        [general, morning, evening].forEach(context.insert)

        let created = try XCTUnwrap(NutrientGroup.create(named: "  Gym  ", among: [general, morning, evening], in: context))
        XCTAssertEqual(created.name, "Gym")
        XCTAssertEqual(created.sortOrder, 5)
        XCTAssertFalse(created.isSystem)
    }

    func testBlankGroupNameCreatesNothing() throws {
        XCTAssertNil(NutrientGroup.create(named: "   ", among: [], in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<NutrientGroup>()), 0)
    }
}
