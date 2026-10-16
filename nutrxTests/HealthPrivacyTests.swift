import XCTest
import SwiftData
@testable import nutrx

/// Guideline 5.1.3 (docs/pro/PLAN.md risks): Health data is read live and never stored. No SwiftData model, which
/// iCloud syncs, has anywhere to keep it.
final class HealthPrivacyTests: XCTestCase {
    func testNoModelHoldsHealthValues() {
        let schema = Schema([UserProfile.self, Nutrient.self, IntakeRecord.self, Exclusion.self, NutrientReminder.self,
                             NutrientGroup.self, UserPreferences.self, LogStack.self, LogStackEntry.self])
        let healthWords = ["sleep", "workout", "energy", "health", "kcal", "heart", "steps"]
        for entity in schema.entities {
            for property in entity.properties {
                let name = property.name.lowercased()
                XCTAssertFalse(healthWords.contains(where: name.contains), "\(entity.name).\(property.name)")
            }
        }
    }

    func testOnlyTheSwitchIsKeptOnTheDevice() {
        // The one thing stored for Health trends: whether the user turned them on.
        XCTAssertEqual(HealthReader.connectedKey, "nutrx.healthConnected")
        let stored = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.lowercased().contains("health") }
        XCTAssertTrue(stored.allSatisfy { $0 == HealthReader.connectedKey || $0.hasPrefix("nutrx.debug.") }, "\(stored)")
    }
}
