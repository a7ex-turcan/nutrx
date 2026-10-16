import Foundation
import SwiftData

extension NutrientGroup {
    /// Moves nutrients to the end of this group, in the order given (the list's order for a selection), after the
    /// nutrients already in it. The only writer of a group move: My Nutrients and Today's Move to Group, one or several.
    func append(_ moving: [Nutrient]) {
        let movingIDs = Set(moving.map(\.persistentModelID))
        var next = ((nutrients ?? []).filter { !movingIDs.contains($0.persistentModelID) }.map(\.groupSortOrder).max() ?? -1) + 1
        for nutrient in moving {
            nutrient.group = self
            nutrient.groupSortOrder = next
            next += 1
        }
    }
}
