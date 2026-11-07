import Foundation
import SwiftData

/// A nutrient excluded on a day, from the early builds' "Exclude for today". Nothing creates one any more (#302); old
/// ones still count where past days are judged (`HistoryLog`, `StreakService`), and the model stays in the CloudKit
/// schema, which can't drop a record type.
@Model
final class Exclusion {
    var nutrient: Nutrient?
    var date: Date = Date.distantPast

    init(nutrient: Nutrient, date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.nutrient = nutrient
    }
}
