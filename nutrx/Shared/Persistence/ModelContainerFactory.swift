import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupID = "group.nutrx-labs.nutrx"
    static let cloudKitContainerID = "iCloud.nutrx-labs.nutrx"

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

        // Try CloudKit-backed configuration first
        let cloudConfig = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            seedGeneralGroupIfNeeded(context: container.mainContext)
            deduplicateSingletons(context: container.mainContext)
            return container
        } catch {
            // Fallback to local-only if CloudKit config fails
            let localConfig = ModelConfiguration(schema: schema, url: storeURL)
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                seedGeneralGroupIfNeeded(context: container.mainContext)
                deduplicateSingletons(context: container.mainContext)
                return container
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    // MARK: - Shared Store URL

    static func sharedStoreURL() -> URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appending(path: "default.store")
    }

    // MARK: - One-Time Migration

    private static func migrateStoreToAppGroupIfNeeded() {
        let fm = FileManager.default
        let destination = sharedStoreURL()

        guard !fm.fileExists(atPath: destination.path()) else { return }

        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldStore = appSupport.appending(path: "default.store")

        guard fm.fileExists(atPath: oldStore.path()) else { return }

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

    // MARK: - Deduplication (CloudKit sync safety)

    @MainActor
    private static func deduplicateSingletons(context: ModelContext) {
        deduplicateGeneralGroups(context: context)
        deduplicateUserProfiles(context: context)
        deduplicateUserPreferences(context: context)
    }

    @MainActor
    private static func deduplicateGeneralGroups(context: ModelContext) {
        let descriptor = FetchDescriptor<NutrientGroup>(
            predicate: #Predicate { $0.isSystem == true }
        )
        guard let systemGroups = try? context.fetch(descriptor),
              systemGroups.count > 1 else { return }

        let keeper = systemGroups[0]
        for duplicate in systemGroups.dropFirst() {
            for nutrient in duplicate.nutrients ?? [] {
                nutrient.group = keeper
            }
            context.delete(duplicate)
        }
    }

    @MainActor
    private static func deduplicateUserProfiles(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profiles = try? context.fetch(descriptor),
              profiles.count > 1 else { return }

        let keeper = profiles.first(where: { $0.onboardingCompleted }) ?? profiles[0]
        for profile in profiles where profile.persistentModelID != keeper.persistentModelID {
            context.delete(profile)
        }
    }

    @MainActor
    private static func deduplicateUserPreferences(context: ModelContext) {
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let prefs = try? context.fetch(descriptor),
              prefs.count > 1 else { return }

        for duplicate in prefs.dropFirst() {
            context.delete(duplicate)
        }
    }
}
