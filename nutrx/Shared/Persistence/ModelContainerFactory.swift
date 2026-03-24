import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupID = "group.nutrx-labs.nutrx"

    static func create() -> ModelContainer {
        migrateStoreToAppGroupIfNeeded()

        let schema = Schema([
            UserProfile.self,
            Nutrient.self,
            IntakeRecord.self,
            Exclusion.self,
            UserPreferences.self,
            NutrientReminder.self,
            NutrientGroup.self,
        ])

        let storeURL = sharedStoreURL()
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedGeneralGroupIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Shared Store URL

    static func sharedStoreURL() -> URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appending(path: "default.store")
    }

    // MARK: - One-Time Migration

    /// Copies the SwiftData store from the app sandbox to the App Group container.
    /// Only runs once — if the App Group store already exists, this is a no-op.
    private static func migrateStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        let destination = sharedStoreURL()

        // If the shared store already exists, nothing to do.
        guard !fm.fileExists(atPath: destination.path()) else { return }

        // Find the old default store in the app sandbox.
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldStore = appSupport.appending(path: "default.store")

        guard fm.fileExists(atPath: oldStore.path()) else { return }

        // Copy main store file + WAL/SHM companions.
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let src = URL(filePath: oldStore.path() + ext)
            let dst = URL(filePath: destination.path() + ext)
            guard fm.fileExists(atPath: src.path()) else { continue }
            try? fm.copyItem(at: src, to: dst)
        }
    }

    // MARK: - Seed

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
