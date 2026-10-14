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

    func testSettingsSummaryCountsStacks() {
        XCTAssertEqual(SettingsSummary.stacks(count: 0), "None")
        XCTAssertEqual(SettingsSummary.stacks(count: 3), "3")
    }
}
