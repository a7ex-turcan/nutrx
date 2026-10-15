import XCTest
import SwiftData
@testable import nutrx

/// Stacks: which entries count, logging with and without changed amounts, "done today", undo, adding.
@MainActor
final class StackLoggingTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func nutrient(_ name: String, step: Double = 100, deleted: Bool = false) -> Nutrient {
        let item = Nutrient(name: name, unit: "mg", step: step, dailyTarget: 400, sortOrder: 0, isDeleted: deleted)
        context.insert(item)
        return item
    }

    /// Morning: Vitamin D 2,000, Omega-3 1,000, Magnesium 400 (added in that order).
    private func morning() -> (LogStack, Nutrient, Nutrient, Nutrient) {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let vitaminD = nutrient("Vitamin D", step: 1000), omega3 = nutrient("Omega-3", step: 500)
        let magnesium = nutrient("Magnesium", step: 200)
        StackLogging.add(vitaminD, to: stack, context: context).amount = 2000
        StackLogging.add(omega3, to: stack, context: context).amount = 1000
        StackLogging.add(magnesium, to: stack, context: context).amount = 400
        return (stack, vitaminD, omega3, magnesium)
    }

    func testAddedNutrientsStartAtTheirStepInOrder() {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let vitaminD = nutrient("Vitamin D", step: 1000), omega3 = nutrient("Omega-3", step: 500)
        StackLogging.add(vitaminD, to: stack, context: context)
        StackLogging.add(omega3, to: stack, context: context)
        let entries = StackLogging.activeEntries(of: stack)
        XCTAssertEqual(entries.map { $0.nutrient?.name }, ["Vitamin D", "Omega-3"])
        XCTAssertEqual(entries.map(\.amount), [1000, 500])
    }

    func testNewStacksGoToTheEnd() {
        let first = StackLogging.createStack(named: "Morning", context: context)
        let second = StackLogging.createStack(named: "Evening", context: context)
        XCTAssertLessThan(first.sortOrder, second.sortOrder)
    }

    func testDeletedNutrientsAreSkipped() {
        let (stack, _, omega3, _) = morning()
        omega3.isDeleted = true
        XCTAssertEqual(StackLogging.activeEntries(of: stack).compactMap { $0.nutrient?.name }, ["Vitamin D", "Magnesium"])
        XCTAssertEqual(StackLogging.summary(of: stack), "Vitamin D, Magnesium")

        let logged = StackLogging.log(stack, context: context)
        XCTAssertEqual(logged.records.count, 2)
        XCTAssertEqual(omega3.intakeRecords?.count ?? 0, 0)
    }

    func testLogsEachEntryAtItsAmountOrTheChangedOne() throws {
        let (stack, vitaminD, omega3, magnesium) = morning()
        let omegaEntry = try XCTUnwrap(StackLogging.activeEntries(of: stack).first { $0.nutrient === omega3 })
        let now = Date()

        let logged = StackLogging.log(stack, amounts: [omegaEntry.persistentModelID: 1500], context: context, now: now)

        XCTAssertEqual(vitaminD.intakeRecords?.map(\.amount), [2000])
        XCTAssertEqual(omega3.intakeRecords?.map(\.amount), [1500])
        XCTAssertEqual(magnesium.intakeRecords?.map(\.amount), [400])
        XCTAssertEqual(logged.records.count, 3)
        XCTAssertEqual(stack.lastLoggedAt, now)
        XCTAssertTrue(StackLogging.isLoggedToday(stack, now: now))
        XCTAssertEqual(omegaEntry.amount, 1000, "a change in the sheet applies to this time only")
    }

    func testZeroAmountsAreSkipped() throws {
        let (stack, vitaminD, _, _) = morning()
        let entry = try XCTUnwrap(StackLogging.activeEntries(of: stack).first { $0.nutrient === vitaminD })
        let logged = StackLogging.log(stack, amounts: [entry.persistentModelID: 0], context: context)
        XCTAssertEqual(logged.records.count, 2)
        XCTAssertEqual(vitaminD.intakeRecords?.count ?? 0, 0)
    }

    func testAStackWithNothingToLogStaysNotLogged() {
        let stack = StackLogging.createStack(named: "Empty", context: context)
        let logged = StackLogging.log(stack, context: context)
        XCTAssertTrue(logged.records.isEmpty)
        XCTAssertNil(stack.lastLoggedAt)
        XCTAssertEqual(StackLogging.summary(of: stack), "No nutrients yet")
    }

    func testLoggedTodayIsPerCalendarDay() {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let now = Date()
        stack.lastLoggedAt = Calendar.current.date(byAdding: .day, value: -1, to: now)
        XCTAssertFalse(StackLogging.isLoggedToday(stack, now: now))
        stack.lastLoggedAt = now
        XCTAssertTrue(StackLogging.isLoggedToday(stack, now: now))
    }

    func testUndoRemovesWhatWasLoggedAndRestoresTheDate() throws {
        let (stack, vitaminD, _, _) = morning()
        let earlier = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        stack.lastLoggedAt = earlier
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000))  // logged separately, must stay
        try context.save()

        let logged = StackLogging.log(stack, context: context)
        StackLogging.undo(logged, of: stack, context: context)

        XCTAssertEqual(stack.lastLoggedAt, earlier)
        XCTAssertEqual(vitaminD.intakeRecords?.map(\.amount), [1000])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IntakeRecord>()), 1)
    }

    func testSteppingNeverGoesBelowOneStep() {
        XCTAssertEqual(StackLogging.stepped(2000, by: 1000, up: true), 3000)
        XCTAssertEqual(StackLogging.stepped(2000, by: 1000, up: false), 1000)
        XCTAssertEqual(StackLogging.stepped(1000, by: 1000, up: false), 1000)
        XCTAssertEqual(StackLogging.stepped(0.5, by: 0.25, up: false), 0.25)
    }

    func testDeletingANutrientForGoodRemovesItsEntries() throws {
        let (stack, vitaminD, _, _) = morning()
        context.delete(vitaminD)
        try context.save()
        XCTAssertEqual(StackLogging.activeEntries(of: stack).count, 2)
    }

    func testDuplicateIDsAreRepairedKeepingTheFirst() {
        let first = StackLogging.createStack(named: "Morning", context: context)
        let second = StackLogging.createStack(named: "Evening", context: context)
        let third = StackLogging.createStack(named: "Night", context: context)
        second.createdAt = first.createdAt.addingTimeInterval(1)
        third.createdAt = first.createdAt.addingTimeInterval(2)
        let shared = first.id
        second.id = shared
        third.id = shared  // as after the migration that added `id`

        XCTAssertTrue(StackLogging.repairDuplicateIDs(context: context))

        XCTAssertEqual(first.id, shared)
        XCTAssertEqual(Set([first.id, second.id, third.id]).count, 3)

        let ids = [first.id, second.id, third.id]
        XCTAssertFalse(StackLogging.repairDuplicateIDs(context: context))
        XCTAssertEqual([first.id, second.id, third.id], ids, "unique ids are left alone")
    }

    func testSettingsSummaryCountsStacks() {
        XCTAssertEqual(SettingsSummary.stacks(count: 0), "None")
        XCTAssertEqual(SettingsSummary.stacks(count: 3), "3")
    }

    // MARK: - Adding to stacks from My Nutrients and the form

    func testToggleAddsAndRemoves() {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let zinc = nutrient("Zinc", step: 15)
        StackLogging.toggle(zinc, in: stack, context: context)
        XCTAssertTrue(StackLogging.contains(stack, zinc))
        XCTAssertEqual(stack.entries?.first?.amount, 15, "joins at one step")
        StackLogging.toggle(zinc, in: stack, context: context)
        XCTAssertFalse(StackLogging.contains(stack, zinc))
        XCTAssertEqual(stack.entries?.count ?? 0, 0)
    }

    func testANewNutrientJoinsThePickedStacksAndCreatesNewOnes() throws {
        let morning = StackLogging.createStack(named: "Morning", context: context)
        let draft = NutrientDraft()
        draft.name = "Zinc"
        draft.unit = "mg"
        draft.step = "15"
        draft.dailyTarget = "15"
        draft.pendingStacks = [.existing(morning.id), .new("Evening")]
        let zinc = try XCTUnwrap(draft.insertNutrient(into: context, group: nil, sortOrder: 0))
        XCTAssertTrue(StackLogging.contains(morning, zinc))
        let stacks = try context.fetch(FetchDescriptor<LogStack>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(stacks.map(\.name), ["Morning", "Evening"])
        XCTAssertTrue(StackLogging.contains(stacks[1], zinc))
    }

    func testCancellingTheFormCreatesNoStack() throws {
        let draft = NutrientDraft()
        draft.pendingStacks = [.new("Evening")]
        draft.reset()  // what the form does before it's opened again
        XCTAssertTrue(draft.pendingStacks.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LogStack>()), 0)
    }

    func testTodaySuggestsAStackUntilThereIsOneOrItsHidden() {
        XCTAssertTrue(StackLogging.suggestsStack(nutrientCount: 3, stackCount: 0, hidden: false))
        XCTAssertFalse(StackLogging.suggestsStack(nutrientCount: 2, stackCount: 0, hidden: false), "too few to stack")
        XCTAssertFalse(StackLogging.suggestsStack(nutrientCount: 5, stackCount: 1, hidden: false))
        XCTAssertFalse(StackLogging.suggestsStack(nutrientCount: 5, stackCount: 0, hidden: true))
    }

    func testStacksRowSummary() {
        XCTAssertEqual(StackLogging.summary(names: []), "None")
        XCTAssertEqual(StackLogging.summary(names: ["Morning"]), "Morning")
        XCTAssertEqual(StackLogging.summary(names: ["Morning", "Evening"]), "Morning and Evening")
        XCTAssertEqual(StackLogging.summary(names: ["A", "B", "C"]), "3 stacks")
    }

    func testScanningKeepsThePickedStacks() {
        let draft = NutrientDraft()
        draft.pendingStacks = [.new("Morning")]
        LabelPrefill.apply(.init(name: "Vitamin D3", unit: "IU", amountPerServing: 1000), to: draft)
        XCTAssertEqual(draft.pendingStacks, [.new("Morning")])
    }

    func testTheNewStackPlaceholderSuggestsAnUnusedName() {
        XCTAssertEqual(StackLogging.suggestedName(existing: []), "Morning")
        XCTAssertEqual(StackLogging.suggestedName(existing: ["morning"]), "Evening")
        XCTAssertEqual(StackLogging.suggestedName(existing: ["Morning", "Evening", "Night", "With meals", "Workout"]), "Stack")
    }
}
