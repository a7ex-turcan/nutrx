import Foundation
import SwiftData

@Model
final class Exclusion {
    var nutrient: Nutrient?
    var date: Date

    init(nutrient: Nutrient, date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.nutrient = nutrient
    }
}
