import SwiftData
@testable import nutrx

extension ModelContainer {
    /// Fresh in-memory store with the full app schema, isolated from the app's real data.
    static func inMemoryForTests() throws -> ModelContainer {
        try ModelContainer(
            for: UserProfile.self, Nutrient.self, IntakeRecord.self, Exclusion.self,
            UserPreferences.self, NutrientReminder.self, NutrientGroup.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
