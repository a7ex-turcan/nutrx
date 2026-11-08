import SwiftData
@testable import nutrx

extension ModelContainer {
    /// Fresh in-memory store with the full app schema, isolated from the app's real data.
    static func inMemoryForTests() throws -> ModelContainer {
        // Every stored model (`ModelContainerFactory.schema`), so a new one is here without a second list.
        try ModelContainer(
            for: ModelContainerFactory.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
