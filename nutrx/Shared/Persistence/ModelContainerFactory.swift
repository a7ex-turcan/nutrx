import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "ModelContainerFactory")

enum ModelContainerFactory {
    static let appGroupID = "group.nutrx-labs.nutrx"
    static let cloudKitContainerID = "iCloud.nutrx-labs.nutrx"
    private static let cloudKitUpgradeKey = "nutrx.hasCompletedCloudKitUpgrade"

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
        let needsCloudKitUpgrade = !UserDefaults.standard.bool(forKey: cloudKitUpgradeKey)

        // Back up existing local store before CloudKit touches it
        if needsCloudKitUpgrade {
            backupStoreFiles(at: storeURL)
        }

        // Try CloudKit-backed configuration first
        let cloudConfig = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            logger.info("CloudKit container created at \(storeURL.path())")

            if needsCloudKitUpgrade {
                migrateFromBackupIfNeeded(into: container, schema: schema)
                UserDefaults.standard.set(true, forKey: cloudKitUpgradeKey)
                cleanupBackupFiles()
            }

            seedGeneralGroupIfNeeded(context: container.mainContext)
            deduplicateSingletons(context: container.mainContext)
            return container
        } catch {
            logger.error("CloudKit container failed: \(error.localizedDescription)")
            // Fallback to local-only if CloudKit config fails
            if needsCloudKitUpgrade {
                UserDefaults.standard.set(true, forKey: cloudKitUpgradeKey)
            }
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

    // MARK: - CloudKit Upgrade Backup & Migration

    private static func backupStoreURL() -> URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appending(path: "pre-cloudkit-backup.store")
    }

    private static func backupStoreFiles(at storeURL: URL) {
        let fm = FileManager.default
        let backupURL = backupStoreURL()

        guard fm.fileExists(atPath: storeURL.path()),
              !fm.fileExists(atPath: backupURL.path()) else { return }

        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let src = URL(filePath: storeURL.path() + ext)
            let dst = URL(filePath: backupURL.path() + ext)
            guard fm.fileExists(atPath: src.path()) else { continue }
            try? fm.copyItem(at: src, to: dst)
        }
        logger.info("Backed up local store before CloudKit upgrade")
    }

    @MainActor
    private static func migrateFromBackupIfNeeded(into cloudContainer: ModelContainer, schema: Schema) {
        let cloudContext = cloudContainer.mainContext

        // If CloudKit container already has data, no migration needed
        let profileCount = (try? cloudContext.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if profileCount > 0 {
            logger.info("CloudKit container already has data (\(profileCount) profiles), skipping migration")
            return
        }

        let backupURL = backupStoreURL()
        guard FileManager.default.fileExists(atPath: backupURL.path()) else {
            logger.info("No backup store found, skipping migration")
            return
        }

        // Open backup with local-only config
        let backupConfig = ModelConfiguration(
            "pre-cloudkit-backup",
            schema: schema,
            url: backupURL,
            cloudKitDatabase: .none
        )

        guard let backupContainer = try? ModelContainer(for: schema, configurations: [backupConfig]) else {
            logger.error("Failed to open backup store for migration")
            return
        }
        let backupContext = backupContainer.mainContext

        // Check backup actually has data
        let backupProfiles = (try? backupContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard !backupProfiles.isEmpty else {
            logger.info("Backup store is empty, skipping migration")
            return
        }

        logger.info("Migrating data from local backup to CloudKit container...")

        // 1. UserProfile
        for old in backupProfiles {
            let new = UserProfile(
                name: old.name, birthdate: old.birthdate,
                weight: old.weight, weightUnit: old.weightUnit,
                height: old.height, heightUnit: old.heightUnit,
                onboardingCompleted: old.onboardingCompleted
            )
            new.createdAt = old.createdAt
            cloudContext.insert(new)
        }

        // 2. UserPreferences
        let backupPrefs = (try? backupContext.fetch(FetchDescriptor<UserPreferences>())) ?? []
        for old in backupPrefs {
            let new = UserPreferences(
                dailyReminderEnabled: old.dailyReminderEnabled,
                hasSeenNotificationBanner: old.hasSeenNotificationBanner,
                streaksEnabled: old.streaksEnabled,
                iCloudSyncEnabled: old.iCloudSyncEnabled,
                hasSeenSyncRestoredBanner: old.hasSeenSyncRestoredBanner,
                hasSeenSyncEnabledBanner: old.hasSeenSyncEnabledBanner
            )
            new.lastReviewRequestedVersion = old.lastReviewRequestedVersion
            new.lastReviewRequestedDate = old.lastReviewRequestedDate
            cloudContext.insert(new)
        }

        // 3. NutrientGroups
        let backupGroups = (try? backupContext.fetch(FetchDescriptor<NutrientGroup>())) ?? []
        var groupMap: [PersistentIdentifier: NutrientGroup] = [:]
        for old in backupGroups {
            let new = NutrientGroup(name: old.name, sortOrder: old.sortOrder, isSystem: old.isSystem)
            new.isCollapsed = old.isCollapsed
            cloudContext.insert(new)
            groupMap[old.persistentModelID] = new
        }

        // 4. Nutrients (depends on groups)
        let backupNutrients = (try? backupContext.fetch(FetchDescriptor<Nutrient>())) ?? []
        var nutrientMap: [PersistentIdentifier: Nutrient] = [:]
        for old in backupNutrients {
            let new = Nutrient(
                name: old.name, unit: old.unit, step: old.step,
                dailyTarget: old.dailyTarget, sortOrder: old.sortOrder,
                isDeleted: old.isDeleted
            )
            new.id = old.id // preserve UUID for widget intents
            new.notes = old.notes
            new.groupSortOrder = old.groupSortOrder
            new.createdAt = old.createdAt
            if let oldGroup = old.group {
                new.group = groupMap[oldGroup.persistentModelID]
            }
            cloudContext.insert(new)
            nutrientMap[old.persistentModelID] = new
        }

        // 5. IntakeRecords (depends on nutrients)
        let backupRecords = (try? backupContext.fetch(FetchDescriptor<IntakeRecord>())) ?? []
        for old in backupRecords {
            if let oldNutrient = old.nutrient, let newNutrient = nutrientMap[oldNutrient.persistentModelID] {
                let new = IntakeRecord(nutrient: newNutrient, amount: old.amount, date: old.date, note: old.note)
                cloudContext.insert(new)
            }
        }

        // 6. Exclusions (depends on nutrients)
        let backupExclusions = (try? backupContext.fetch(FetchDescriptor<Exclusion>())) ?? []
        for old in backupExclusions {
            if let oldNutrient = old.nutrient, let newNutrient = nutrientMap[oldNutrient.persistentModelID] {
                let new = Exclusion(nutrient: newNutrient, date: old.date)
                cloudContext.insert(new)
            }
        }

        // 7. NutrientReminders (depends on nutrients)
        let backupReminders = (try? backupContext.fetch(FetchDescriptor<NutrientReminder>())) ?? []
        for old in backupReminders {
            if let oldNutrient = old.nutrient, let newNutrient = nutrientMap[oldNutrient.persistentModelID] {
                let new = NutrientReminder(nutrient: newNutrient, timeOfDay: old.timeOfDay)
                cloudContext.insert(new)
            }
        }

        try? cloudContext.save()

        let migratedNutrients = backupNutrients.count
        let migratedRecords = backupRecords.count
        logger.info("Migration complete: \(migratedNutrients) nutrients, \(migratedRecords) intake records")
    }

    private static func cleanupBackupFiles() {
        let fm = FileManager.default
        let backupURL = backupStoreURL()
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let file = URL(filePath: backupURL.path() + ext)
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - App Group Migration (pre-widget → App Group)

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
