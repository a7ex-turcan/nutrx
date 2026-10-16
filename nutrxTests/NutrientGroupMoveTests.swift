import SwiftData
import XCTest
@testable import nutrx

/// Moving one or several nutrients to a group (#98): appended after the group's own, in the order given.
final class NutrientGroupMoveTests: XCTestCase {
    func testSeveralAreAppendedInTheirOrder() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let morning = NutrientGroup(name: "Morning", sortOrder: 0)
        let evening = NutrientGroup(name: "Evening", sortOrder: 1)
        context.insert(morning)
        context.insert(evening)
        func nutrient(_ name: String, in group: NutrientGroup, order: Int) -> Nutrient {
            let nutrient = Nutrient(name: name, unit: "mg", step: 1, dailyTarget: 1, sortOrder: order)
            context.insert(nutrient)
            nutrient.group = group
            nutrient.groupSortOrder = order
            return nutrient
        }
        let vitaminD = nutrient("Vitamin D", in: morning, order: 0)
        let omega = nutrient("Omega-3", in: morning, order: 1)
        let magnesium = nutrient("Magnesium", in: evening, order: 0)
        let zinc = nutrient("Zinc", in: evening, order: 5)
        try context.save()

        evening.append([vitaminD, omega])
        XCTAssertEqual(vitaminD.group, evening)
        XCTAssertEqual(omega.group, evening)
        XCTAssertEqual(vitaminD.groupSortOrder, 6, "after Zinc, the highest in Evening")
        XCTAssertEqual(omega.groupSortOrder, 7)
        XCTAssertEqual(magnesium.groupSortOrder, 0)
        XCTAssertEqual(zinc.groupSortOrder, 5)

        // Moving within the same group puts them at its end, ignoring their own old positions.
        evening.append([magnesium])
        XCTAssertEqual(magnesium.groupSortOrder, 8)
    }
}
