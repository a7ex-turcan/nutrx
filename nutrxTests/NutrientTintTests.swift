import SwiftData
import XCTest
@testable import nutrx

/// DESIGN.md §3 — tint storage and the stable id-derived fallback.
final class NutrientTintTests: XCTestCase {

    // Expected values computed independently: sum of the UUID's bytes mod 8, indexed into the pinned
    // order green, teal, blue, indigo, pink, coral, amber, brown. If one of these fails, a change has
    // recoloured every nutrient whose tint was never chosen.
    func testFallbackIsPinnedForKnownIDs() throws {
        let cases: [(String, NutrientTint)] = [
            ("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", .amber),   // byte sum 2038
            ("6F9619FF-8B86-D011-B42D-00C04FC964FF", .indigo),  // byte sum 2091
            ("00000000-0000-0000-0000-000000000000", .green),   // byte sum 0
        ]
        for (string, expected) in cases {
            let id = try XCTUnwrap(UUID(uuidString: string))
            XCTAssertEqual(NutrientTint.fallback(for: id), expected, string)
        }
    }

    func testNutrientWithoutChosenTintUsesFallback() throws {
        let nutrient = try makeNutrient()
        XCTAssertEqual(nutrient.tintRaw, "")
        XCTAssertEqual(nutrient.tint, NutrientTint.fallback(for: nutrient.id))
    }

    func testChoosingTintStoresRawValue() throws {
        let nutrient = try makeNutrient()
        nutrient.tint = .coral
        XCTAssertEqual(nutrient.tintRaw, "coral")
        XCTAssertEqual(nutrient.tint, .coral)
    }

    func testChosenGreenIsNotOverriddenByFallback() throws {
        let nutrient = try makeNutrient()
        nutrient.id = try XCTUnwrap(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))  // falls back to amber
        nutrient.tint = .green
        XCTAssertEqual(nutrient.tint, .green)
    }

    func testUnknownStoredTintFallsBack() throws {
        let nutrient = try makeNutrient()
        nutrient.tintRaw = "magenta"  // e.g. synced from a newer app version
        XCTAssertEqual(nutrient.tint, NutrientTint.fallback(for: nutrient.id))
    }

    func testDefaultSymbolIsPills() throws {
        XCTAssertEqual(try makeNutrient().symbolName, "pills")
    }

    private func makeNutrient() throws -> Nutrient {
        let container = try ModelContainer.inMemoryForTests()
        let nutrient = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        container.mainContext.insert(nutrient)
        retainedContainers.append(container)
        return nutrient
    }

    /// Keeps each test's container alive for as long as its models are used.
    private var retainedContainers: [ModelContainer] = []
}
