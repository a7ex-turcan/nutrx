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

    func testANewNutrientKeepsItsUsualTimeStart() throws {
        let draft = NutrientDraft()
        draft.name = "Zinc"
        draft.unit = "mg"
        draft.step = "10"
        draft.dailyTarget = "10"
        draft.usualReminderMinutes = 510
        let nutrient = try XCTUnwrap(draft.insertNutrient(into: context, group: nil, sortOrder: 0))
        XCTAssertEqual(nutrient.usualReminderMinutes, 510, "at its usual time from 8:30, with no set reminders (#137)")
        XCTAssertTrue(nutrient.remindsAtUsualTime)
        XCTAssertNotEqual(draft.snapshot, NutrientDraft().snapshot)
    }

    func testResetRestoresDefaults() {
        let draft = NutrientDraft()
        draft.tint = .pink
        draft.symbolName = "heart"
        draft.reset()
        XCTAssertEqual(draft.tint, .green)
        XCTAssertEqual(draft.symbolName, "pills")
    }

    // MARK: - Pending reminders

    func testPendingRemindersSkipADuplicateTimeAndStaySorted() {
        let calendar = Calendar(identifier: .gregorian)
        func time(_ hour: Int, _ minute: Int, day: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        let draft = NutrientDraft()

        XCTAssertTrue(draft.addPendingReminder(time(13, 0), calendar: calendar))
        XCTAssertTrue(draft.addPendingReminder(time(9, 30), calendar: calendar))
        XCTAssertFalse(draft.addPendingReminder(time(13, 0, day: 1), calendar: calendar), "same hour and minute")

        XCTAssertEqual(draft.pendingReminderTimes, [time(9, 30), time(13, 0)])
        XCTAssertTrue(draft.hasPendingReminder(at: time(9, 30, day: 3), calendar: calendar))
        XCTAssertFalse(draft.hasPendingReminder(at: time(9, 31), calendar: calendar))
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

    // MARK: - Saving (#347)

    func testAddAndSaveWriteTheStoreStraightAway() throws {
        let draft = NutrientDraft()
        draft.name = "Iron"
        draft.unit = "mg"
        draft.step = "9"
        draft.dailyTarget = "18"
        let iron = try XCTUnwrap(draft.insertNutrient(into: context, group: nil, sortOrder: 0))
        XCTAssertFalse(context.hasChanges, "Add saves, rather than waiting for the autosave")

        draft.dailyTarget = "27"
        draft.apply(to: iron)
        XCTAssertFalse(context.hasChanges, "Save saves too")
        XCTAssertEqual(iron.dailyTarget, 27)
    }

    // MARK: - Dose plans (#135)

    /// A plan from 30 days ago: 200 mg for a week, then 400 mg for a week, kept since.
    private func plannedNutrient() -> (Nutrient, start: Date) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: .now))!
        let nutrient = Nutrient(name: "Magnesium", unit: "mg", step: 200, dailyTarget: 100, sortOrder: 0)
        nutrient.dosePlanRaw = NutrientDosePlan().creating(
            steps: [.init(goal: NutrientGoal(target: 200), days: 7), .init(goal: NutrientGoal(target: 400), days: 7)],
            end: .keep, start: start, base: NutrientGoal(target: 100), today: start).encode()
        context.insert(nutrient)
        return (nutrient, start)
    }

    func testTheFormFillsAndSavesTheDosePlan() {
        let (nutrient, start) = plannedNutrient()
        let draft = NutrientDraft()
        draft.populate(from: nutrient)
        XCTAssertEqual(draft.dosePlan, nutrient.dosePlan().plan)
        XCTAssertEqual(draft.dosePlanGoal()?.target, 400, "today's goal, from the plan")

        draft.dosePlan = nil
        draft.apply(to: nutrient)
        XCTAssertNil(nutrient.dosePlan().plan)
        XCTAssertEqual(nutrient.dailyTarget, 400, "removing a kept plan keeps its goal")
        XCTAssertEqual(nutrient.goal(on: Calendar.current.date(byAdding: .day, value: 2, to: start)!).target, 200,
                       "past days keep their goals")
    }

    func testANewNutrientStartsItsPlanTheDayItsAdded() throws {
        let draft = NutrientDraft()
        draft.name = "Magnesium"
        draft.unit = "mg"
        draft.step = "100"
        draft.dailyTarget = "100"
        let today = Calendar.current.startOfDay(for: .now)
        draft.dosePlan = NutrientDosePlan.Plan(
            start: today, steps: [.init(goal: NutrientGoal(target: 200), days: 7), .init(goal: NutrientGoal(target: 400), days: 7)],
            end: .keep, appliesFrom: today)
        let nutrient = try XCTUnwrap(draft.insertNutrient(into: context, group: nil, sortOrder: 0))
        XCTAssertEqual(nutrient.goal().target, 200)
        XCTAssertEqual(nutrient.dailyTarget, 100, "the base goal is the form's")
        XCTAssertEqual(nutrient.dosePlan().plan?.steps.count, 2)
    }

    func testTheSheetsDoneSetsTheDurationAndAMissingGoal() {
        let today = Calendar.current.startOfDay(for: .now)
        let draft = NutrientDraft()
        let stops = NutrientDosePlan.Plan(
            start: today, steps: [.init(goal: NutrientGoal(target: 200), days: 3), .init(goal: NutrientGoal(target: 100), days: 4)],
            end: .stop, appliesFrom: today)
        draft.setDosePlan(stops)
        XCTAssertEqual(draft.endDate, Calendar.current.date(byAdding: .day, value: 6, to: today), "ends with the plan")
        XCTAssertEqual(draft.dailyTarget.parsedDouble, 200, "no goal typed yet: the first step's")

        var keeps = stops
        keeps.end = .keep
        draft.dailyTarget = "150"
        draft.setDosePlan(keeps)
        XCTAssertNil(draft.endDate, "the end it set is lifted")
        XCTAssertEqual(draft.dailyTarget.parsedDouble, 150, "a typed goal stays")

        draft.setDosePlan(stops)
        draft.setDosePlan(nil)
        XCTAssertNil(draft.endDate)
        XCTAssertNil(draft.dosePlan)
    }
}
