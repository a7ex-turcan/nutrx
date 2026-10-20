import CoreData
import SwiftData
import XCTest
@testable import nutrx

/// No stored property may share a name with an `NSManagedObject` member. Core Data reads attributes by name, so a
/// field called `isDeleted` read back as the built-in "being deleted" flag (always false), and iCloud sync brought
/// removed nutrients back (#114). A CloudKit store can't rename a property, so the clash has to be caught before it
/// ships (#143).
final class ManagedObjectNameTests: XCTestCase {
    /// Kept only so the old value can be copied into `isRemoved` (CLAUDE.md, Soft deletes); never read or written.
    private let allowed: Set<String> = ["Nutrient.isDeleted"]

    func testNoStoredPropertyClashesWithNSManagedObject() throws {
        let models: [any PersistentModel.Type] = ModelContainerFactory.schema.entities.compactMap { _ in nil }
            + [UserProfile.self, Nutrient.self, IntakeRecord.self, Exclusion.self, UserPreferences.self,
               NutrientReminder.self, NutrientGroup.self, LogStack.self, LogStackEntry.self]
        let model = try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(for: models))
        XCTAssertEqual(model.entities.count, ModelContainerFactory.schema.entities.count,
                       "a model was added to the schema but not to this test")

        var clashes: [String] = []
        for entity in model.entities {
            for name in entity.propertiesByName.keys {
                // KVC finds a getter called `name` or `isName`, so both spellings clash.
                let getters = [name, "is" + name.prefix(1).uppercased() + name.dropFirst()]
                let clashing = getters.filter { NSManagedObject.instancesRespond(to: NSSelectorFromString($0)) }
                let key = "\(entity.name ?? "?").\(name)"
                if !clashing.isEmpty && !allowed.contains(key) {
                    clashes.append("\(key) (NSManagedObject has \(clashing.joined(separator: ", ")))")
                }
            }
        }
        XCTAssertTrue(clashes.isEmpty, "Rename before shipping; a CloudKit store can't rename later: \(clashes)")
    }

    func testTheCheckCatchesTheKnownClash() {
        XCTAssertTrue(NSManagedObject.instancesRespond(to: NSSelectorFromString("isDeleted")))
        XCTAssertTrue(NSManagedObject.instancesRespond(to: NSSelectorFromString("description")))
        XCTAssertFalse(NSManagedObject.instancesRespond(to: NSSelectorFromString("isRemoved")))
    }
}
