import SwiftData

enum ModelContainerFactory {
    static func create() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            Nutrient.self,
            IntakeRecord.self,
            Exclusion.self,
            UserPreferences.self,
            NutrientReminder.self,
            NutrientGroup.self,
        ])
        let configuration = ModelConfiguration(schema: schema)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedGeneralGroupIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    @MainActor
    private static func seedGeneralGroupIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<NutrientGroup>()
        let existingGroups = (try? context.fetch(descriptor)) ?? []
        if existingGroups.isEmpty {
            let general = NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true)
            context.insert(general)
        }
    }
}
