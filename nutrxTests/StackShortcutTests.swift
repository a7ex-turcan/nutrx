import AppIntents
import XCTest
import SwiftData
@testable import nutrx

/// Siri / Shortcuts stacks: picking stacks by name, what "Log Stack" records and says, the Siri tip's phrase.
@MainActor
final class StackShortcutTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let enUS = Locale(identifier: "en_US")

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    private func nutrient(_ name: String, unit: String = "mg", step: Double = 100) -> Nutrient {
        let item = Nutrient(name: name, unit: unit, step: step, dailyTarget: 400, sortOrder: 0)
        context.insert(item)
        return item
    }

    /// Morning: Vitamin D 2,000 IU, Omega-3 1,000 mg.
    private func morning() -> (LogStack, Nutrient, Nutrient) {
        let stack = StackLogging.createStack(named: "Morning", context: context)
        let vitaminD = nutrient("Vitamin D", unit: "IU", step: 1000), omega3 = nutrient("Omega-3", step: 500)
        StackLogging.add(vitaminD, to: stack, context: context).amount = 2000
        StackLogging.add(omega3, to: stack, context: context).amount = 1000
        return (stack, vitaminD, omega3)
    }

    // MARK: - Logging

    func testLogsEveryEntryAndSaysWhat() throws {
        let (stack, vitaminD, omega3) = morning()
        let now = Date()

        let said = try StackShortcutLogging.log(stackID: stack.id, context: context, now: now, locale: enUS)

        XCTAssertEqual(said, "Logged Morning: 2,000 IU Vitamin D and 1,000 mg Omega-3.")
        XCTAssertEqual(vitaminD.intakeRecords?.map(\.amount), [2000])
        XCTAssertEqual(omega3.intakeRecords?.map(\.amount), [1000])
        XCTAssertEqual(stack.lastLoggedAt, now)
    }

    func testSkipsDeletedNutrientsAndUnitlessAmountsReadCleanly() throws {
        let (stack, _, omega3) = morning()
        let water = nutrient("Water", unit: "", step: 1)
        StackLogging.add(water, to: stack, context: context)
        // Soft-deleted after the last save: read right after a save, `Nutrient.isDeleted` can be stale (#56).
        omega3.isDeleted = true

        let said = try StackShortcutLogging.log(stackID: stack.id, context: context, locale: enUS)

        XCTAssertEqual(said, "Logged Morning: 2,000 IU Vitamin D and 1 Water.")
        XCTAssertEqual(omega3.intakeRecords?.count ?? 0, 0)
    }

    func testAnUnknownStackThrows() {
        XCTAssertThrowsError(try StackShortcutLogging.log(stackID: UUID(), context: context)) {
            XCTAssertEqual($0 as? StackShortcutLogging.Failure, .stackNotFound)
        }
    }

    func testAnEmptyStackThrowsAndLogsNothing() throws {
        let stack = StackLogging.createStack(named: "Evening", context: context)
        XCTAssertThrowsError(try StackShortcutLogging.log(stackID: stack.id, context: context)) {
            XCTAssertEqual($0 as? StackShortcutLogging.Failure, .nothingToLog)
        }
        XCTAssertNil(stack.lastLoggedAt)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IntakeRecord>()), 0)
    }

    // MARK: - Lookup

    func testStacksHaveTheirOwnIDs() {
        let first = StackLogging.createStack(named: "Morning", context: context)
        let second = StackLogging.createStack(named: "Evening", context: context)
        XCTAssertNotEqual(first.id, second.id)
    }

    func testSuggestionsAreLoggableStacksInTodaysOrder() {
        let (morningStack, _, omega3) = morning()
        let empty = StackLogging.createStack(named: "Empty", context: context)
        let evening = StackLogging.createStack(named: "Evening", context: context)
        StackLogging.add(omega3, to: evening, context: context)
        morningStack.sortOrder = 5  // now after Evening

        XCTAssertEqual(StackEntityQuery.loggableStacks(in: context).map(\.name), ["Evening", "Morning"])
        // An empty stack can still be resolved by id (and then says it has nothing to log).
        XCTAssertTrue(StackEntityQuery.stacks(in: context).contains { $0.id == empty.id })
    }

    func testMatchingIgnoresCaseAndAccentsWithPrefixesFirst() {
        let entities = ["Late morning", "Morning", "Après-sport"].map {
            StackEntity(id: UUID(), name: $0, summary: "")
        }
        XCTAssertEqual(StackEntityQuery.matching("morn", in: entities).map(\.name), ["Morning", "Late morning"])
        XCTAssertEqual(StackEntityQuery.matching("apres", in: entities).map(\.name), ["Après-sport"])
        XCTAssertEqual(StackEntityQuery.matching("  ", in: entities).count, 3)
    }

    func testEntityShowsTheStacksNutrients() {
        let (stack, _, _) = morning()
        let entity = StackEntity(stack)
        XCTAssertEqual(entity.id, stack.id)
        XCTAssertEqual(entity.name, "Morning")
        XCTAssertEqual(entity.summary, "Vitamin D, Omega-3")
    }

    // MARK: - Siri tip

    func testTheSiriTipNamesTheApp() {
        XCTAssertEqual(StackShortcutLogging.siriPhrase(for: "Morning"), "Log my Morning stack with nutrx")
    }
}
