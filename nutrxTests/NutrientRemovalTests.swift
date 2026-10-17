import CoreData
import SwiftData
import XCTest
@testable import nutrx

/// Removing a nutrient sticks. The flag used to be `isDeleted`, which is also `NSManagedObject`'s own property: Core
/// Data read the stored value by name as false, so iCloud sync brought removed nutrients back after a relaunch, and
/// the flag could read false right after a save (#56). `isRemoved` replaces it; old removals are copied over.
final class NutrientRemovalTests: XCTestCase {
    private func storeURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("removal-\(UUID()).store")
    }

    private func open(_ url: URL) throws -> ModelContainer {
        let schema = ModelContainerFactory.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url,
                                                                                   cloudKitDatabase: .none)])
    }

    func testTheFlagReadsBackAfterASave() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let nutrient = Nutrient(name: "Iron", unit: "mg", step: 1, dailyTarget: 18, sortOrder: 0)
        context.insert(nutrient)
        try context.save()
        nutrient.isRemoved = true
        try context.save()
        XCTAssertTrue(nutrient.isRemoved)
        XCTAssertFalse(nutrient.isRunning())
    }

    /// What CloudKit sync and Core Data see: the stored flag, read by its name.
    func testCoreDataReadsTheStoredFlagByName() throws {
        let url = storeURL()
        do {
            let container = try open(url)
            let context = container.mainContext
            let nutrient = Nutrient(name: "Iron", unit: "mg", step: 1, dailyTarget: 18, sortOrder: 0)
            context.insert(nutrient)
            nutrient.isRemoved = true
            try context.save()
        }
        let models: [any PersistentModel.Type] = [UserProfile.self, Nutrient.self, IntakeRecord.self, Exclusion.self,
                                                  UserPreferences.self, NutrientReminder.self, NutrientGroup.self,
                                                  LogStack.self, LogStackEntry.self]
        let model = try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(for: models))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        let object = try XCTUnwrap(context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Nutrient")).first)
        XCTAssertEqual(object.value(forKey: "isRemoved") as? Bool, true)
    }

    func testOldRemovalsAreCopiedAndNothingComesBack() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let removedBefore = Nutrient(name: "Iron", unit: "mg", step: 1, dailyTarget: 18, sortOrder: 0)
        removedBefore.isDeleted = true
        let removedNow = Nutrient(name: "Zinc", unit: "mg", step: 1, dailyTarget: 11, sortOrder: 1, isRemoved: true)
        let kept = Nutrient(name: "Magnesium", unit: "mg", step: 100, dailyTarget: 400, sortOrder: 2)
        [removedBefore, removedNow, kept].forEach(context.insert)
        try context.save()

        ModelContainerFactory.copyLegacyRemovals(context: context)

        let removed = try context.fetch(FetchDescriptor<Nutrient>(predicate: #Predicate { $0.isRemoved }))
        XCTAssertEqual(Set(removed.map(\.name)), ["Iron", "Zinc"])
    }

    /// A store from 2.2 (60) and earlier opens with the CloudKit configuration (renaming a property there fails
    /// and the app can't start), and its removed nutrients stay removed.
    func testAStoreFromBeforeOpensAndKeepsRemovedNutrients() throws {
        let url = storeURL()
        do {
            let old = try ModelContainer(for: Schema([Before.Nutrient.self]),
                                         configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)])
            old.mainContext.insert(Before.Nutrient(name: "Iron", isDeleted: true))
            old.mainContext.insert(Before.Nutrient(name: "Zinc", isDeleted: false))
            try old.mainContext.save()
        }
        let schema = ModelContainerFactory.schema
        let cloud = ModelConfiguration(schema: schema, url: url,
                                       cloudKitDatabase: .private(ModelContainerFactory.cloudKitContainerID))
        let container = try ModelContainer(for: schema, configurations: [cloud])
        let context = container.mainContext
        ModelContainerFactory.copyLegacyRemovals(context: context)
        let nutrients = try context.fetch(FetchDescriptor<Nutrient>(sortBy: [SortDescriptor(\.name)]))
        XCTAssertEqual(nutrients.map(\.name), ["Iron", "Zinc"])
        XCTAssertEqual(nutrients.map(\.isRemoved), [true, false])
    }
}

/// `Nutrient` as 2.2 (60) and earlier stored it, with only the fields this test needs.
private enum Before {
    @Model
    final class Nutrient {
        var name: String = ""
        var isDeleted: Bool = false

        init(name: String, isDeleted: Bool) {
            self.name = name
            self.isDeleted = isDeleted
        }
    }
}
