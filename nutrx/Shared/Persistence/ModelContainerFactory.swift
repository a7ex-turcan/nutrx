import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "ModelContainerFactory")

enum ModelContainerFactory {
    static let appGroupID = "group.nutrx-labs.nutrx"
    static let cloudKitContainerID = "iCloud.nutrx-labs.nutrx"
    private static let cloudKitUpgradeKey = "nutrx.hasCompletedCloudKitUpgrade"

    static var schema: Schema {
        Schema([
            UserProfile.self,
            Nutrient.self,
            IntakeRecord.self,
            Exclusion.self,
            UserPreferences.self,
            NutrientReminder.self,
            NutrientGroup.self,
            LogStack.self,
            LogStackEntry.self,
        ])
    }

    /// The shared App Group store without CloudKit, for app extensions (the widget's "+" buttons).
    ///
    /// Extensions have no iCloud entitlement — a CloudKit configuration there can crash — and must not run the
    /// app's one-off steps in `create()` (store move, CloudKit-upgrade backup / migration keyed on their own
    /// `UserDefaults`, seeding, dedup). What they write lands in the shared store's history, and the app's
    /// CloudKit mirroring exports it the next time the app runs. Read-only callers (complications) pass
    /// `allowsSave: false`.
    static func createForExtension(allowsSave: Bool = true) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: sharedStoreURL(), allowsSave: allowsSave,
                                               cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func create() -> ModelContainer {
        migrateStoreToAppGroupIfNeeded()

        let schema = Self.schema

        let storeURL = sharedStoreURL()
        #if os(iOS)
        // The Watch never had the switch, so it keeps syncing.
        ICloudSync.adoptLegacyChoice(storeExists: FileManager.default.fileExists(atPath: storeURL.path()),
                                     legacy: legacySyncChoice)
        #endif

        guard ICloudSync.isEnabled() else {
            let localConfig = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                logger.info("iCloud sync is off on this device: local store at \(storeURL.path(), privacy: .public)")
                seedGeneralGroupIfNeeded(context: container.mainContext)
                deduplicateSingletons(context: container.mainContext)
                copyLegacyRemovals(context: container.mainContext)
                return container
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }

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
            // Interpolated strings are redacted outside a debugger unless marked public; neither the store path
            // (the App Group container) nor an error description is personal data.
            logger.info("CloudKit container created at \(storeURL.path(), privacy: .public)")
            ICloudSync.isActive = true

            if needsCloudKitUpgrade {
                migrateFromBackupIfNeeded(into: container, schema: schema)
                UserDefaults.standard.set(true, forKey: cloudKitUpgradeKey)
                cleanupBackupFiles()
            }

            seedGeneralGroupIfNeeded(context: container.mainContext)
            deduplicateSingletons(context: container.mainContext)
            copyLegacyRemovals(context: container.mainContext)
            return container
        } catch {
            // The full error (domain, code, underlying error), not localizedDescription: for SwiftData / Core Data
            // that's often just "The operation couldn't be completed."
            logger.error("CloudKit container failed: \(String(describing: error), privacy: .public)")
            // Fallback to local-only if CloudKit config fails
            if needsCloudKitUpgrade {
                UserDefaults.standard.set(true, forKey: cloudKitUpgradeKey)
            }
            let localConfig = ModelConfiguration(schema: schema, url: storeURL)
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                seedGeneralGroupIfNeeded(context: container.mainContext)
                deduplicateSingletons(context: container.mainContext)
                copyLegacyRemovals(context: container.mainContext)
                return container
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    /// The old synced `UserPreferences.iCloudSyncEnabled`, read without opening the store for sync. Nil when the
    /// store can't be read.
    private static func legacySyncChoice() -> Bool? {
        guard let container = try? createForExtension(allowsSave: false),
              let preferences = try? container.mainContext.fetch(FetchDescriptor<UserPreferences>())
        else { return nil }
        return preferences.first?.iCloudSyncEnabled ?? true
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

        let backupContainer: ModelContainer
        do {
            backupContainer = try ModelContainer(for: schema, configurations: [backupConfig])
        } catch {
            logger.error("Failed to open backup store for migration: \(String(describing: error), privacy: .public)")
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
                isRemoved: old.isRemoved || old.isDeleted
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

    // MARK: - Removed nutrients

    static let legacyRemovalsCopiedKey = "nutrx.copiedLegacyRemovals"

    /// Nutrients removed under the old `Nutrient.isDeleted` flag become `isRemoved`, once per device (a predicate fetch
    /// reads the stored value correctly). Only once, so a stale old flag can't remove a nutrient later; it only ever
    /// removes, never brings one back.
    @MainActor
    static func copyLegacyRemovals(context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: legacyRemovalsCopiedKey) else { return }
        let descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.isDeleted && !$0.isRemoved })
        let legacy = (try? context.fetch(descriptor)) ?? []
        for nutrient in legacy {
            nutrient.isRemoved = true
        }
        do {
            if !legacy.isEmpty { try context.save() }
            defaults.set(true, forKey: legacyRemovalsCopiedKey)
            logger.info("Copied \(legacy.count, privacy: .public) removed nutrients to isRemoved")
        } catch {
            // Not marked done, so the next launch tries again.
            logger.error("Copying removed nutrients failed: \(String(describing: error), privacy: .public)")
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

/// Whether this device syncs with iCloud (#113). The choice is per device, in UserDefaults. The old
/// `UserPreferences.iCloudSyncEnabled` synced itself to every device, and nothing read it, so nutrx kept syncing
/// with the switch off. The store opens with or without CloudKit at launch, so a change applies the next time
/// nutrx opens.
enum ICloudSync {
    static let enabledKey = "nutrx.iCloudSyncEnabled"

    /// This device's choice: on unless turned off.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Whether the store opened at this launch syncs. Set by `ModelContainerFactory.create()`.
    fileprivate(set) static var isActive = false

    /// The first launch with the per-device choice keeps what this device's switch showed (the old synced flag),
    /// when there's a store to read it from. A fresh install starts on, so an "off" synced from another device can't
    /// turn a new device off. If an existing store can't be read (`legacy` is nil), the choice stays unset so the next
    /// launch tries again.
    static func adoptLegacyChoice(storeExists: Bool, legacy: () -> Bool?, defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: enabledKey) == nil else { return }
        if !storeExists {
            defaults.set(true, forKey: enabledKey)
        } else if let choice = legacy() {
            defaults.set(choice, forKey: enabledKey)
        }
    }
}
