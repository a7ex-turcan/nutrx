import AppIntents
import XCTest
import SwiftData
@testable import nutrx

/// Siri / Shortcuts logging: picking nutrients by name, Today's order, and what "Log Nutrient" records and says.
@MainActor
final class NutrientShortcutTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let enUS = Locale(identifier: "en_US")

    override func setUp() async throws {
        container = try ModelContainer.inMemoryForTests()
    }

    override func tearDown() async throws {
        container = nil
    }

    @discardableResult
    private func nutrient(_ name: String, unit: String = "mg", step: Double = 100, target: Double = 400,
                          group: NutrientGroup? = nil, order: Int = 0, deleted: Bool = false) -> Nutrient {
        let item = Nutrient(name: name, unit: unit, step: step, dailyTarget: target, sortOrder: order, isDeleted: deleted)
        item.group = group
        item.groupSortOrder = order
        context.insert(item)
        return item
    }

    // MARK: - Order and lookup

    func testActiveNutrientsFollowTodaysOrderWithGeneralLast() {
        let morning = NutrientGroup(name: "Morning", sortOrder: 0)
        let evening = NutrientGroup(name: "Evening", sortOrder: 1)
        context.insert(morning)
        context.insert(evening)
        nutrient("Water", order: 0)  // no group: General, last
        nutrient("Magnesium", group: evening, order: 0)
        nutrient("Omega-3", group: morning, order: 1)
        nutrient("Vitamin D", group: morning, order: 0)
        nutrient("Old", group: morning, order: 2, deleted: true)

        let names = NutrientEntityQuery.activeNutrients(in: context).map(\.name)
        XCTAssertEqual(names, ["Vitamin D", "Omega-3", "Magnesium", "Water"])
    }

    func testMatchingIgnoresCaseAndAccentsAndPutsPrefixesFirst() {
        let entities = ["Vitamin D", "Omega-3", "Protéine", "D-Mannose"].map {
            NutrientEntity(id: UUID(), name: $0, unit: "", step: 1)
        }
        XCTAssertEqual(NutrientEntityQuery.matching("d", in: entities).map(\.name), ["D-Mannose", "Vitamin D"])
        XCTAssertEqual(NutrientEntityQuery.matching("proteine", in: entities).map(\.name), ["Protéine"])
        XCTAssertEqual(NutrientEntityQuery.matching("  ", in: entities).count, 4)
        XCTAssertTrue(NutrientEntityQuery.matching("zinc", in: entities).isEmpty)
    }

    // MARK: - Logging

    func testLogsOneStepWhenNoAmountIsGiven() throws {
        let vitaminD = nutrient("Vitamin D", unit: "IU", step: 1000, target: 4000)
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 2000))

        let logged = try NutrientShortcutLogging.log(nutrientID: vitaminD.id, amount: nil, context: context,
                                                     locale: enUS)

        XCTAssertEqual(logged.amount, 1000)
        XCTAssertEqual(logged.confirmation, "Logged 1,000 IU of Vitamin D. 3,000 of 4,000 IU today.")
        XCTAssertEqual(vitaminD.intakeRecords?.count, 2)
    }

    func testLogsTheGivenAmount() throws {
        let water = nutrient("Water", unit: "L", step: 0.25, target: 2.5)

        let logged = try NutrientShortcutLogging.log(nutrientID: water.id, amount: 0.5, context: context, locale: enUS)

        XCTAssertEqual(logged.amount, 0.5)
        XCTAssertEqual(logged.confirmation, "Logged 0.5 L of Water. 0.5 of 2.5 L today.")
    }

    func testOnlyTodaysRecordsCountTowardTheTotal() throws {
        let vitaminD = nutrient("Vitamin D", unit: "IU", step: 1000, target: 4000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 3000, date: yesterday))

        let logged = try NutrientShortcutLogging.log(nutrientID: vitaminD.id, amount: nil, context: context,
                                                     locale: enUS)

        XCTAssertEqual(logged.confirmation, "Logged 1,000 IU of Vitamin D. 1,000 of 4,000 IU today.")
    }

    func testRejectsAnAmountThatIsNotAboveZero() {
        let vitaminD = nutrient("Vitamin D", unit: "IU", step: 1000, target: 4000)
        for amount in [0.0, -500] {
            XCTAssertThrowsError(try NutrientShortcutLogging.log(nutrientID: vitaminD.id, amount: amount,
                                                                 context: context)) {
                XCTAssertEqual($0 as? NutrientShortcutLogging.Failure, .amountNotPositive)
            }
        }
        XCTAssertEqual(vitaminD.intakeRecords?.count ?? 0, 0)
    }

    func testRejectsADeletedOrUnknownNutrient() {
        let old = nutrient("Old", deleted: true)
        for id in [old.id, UUID()] {
            XCTAssertThrowsError(try NutrientShortcutLogging.log(nutrientID: id, amount: nil, context: context)) {
                XCTAssertEqual($0 as? NutrientShortcutLogging.Failure, .nutrientNotFound)
            }
        }
    }

    func testEntityShowsTheStepAsItsSubtitle() {
        let entity = NutrientEntity(id: UUID(), name: "Vitamin D", unit: "IU", step: 1000)
        XCTAssertEqual(String(localized: entity.displayRepresentation.title), "Vitamin D")
    }
}
