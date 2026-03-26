import Foundation
import SwiftData

@Model
final class IntakeRecord {
    var nutrient: Nutrient?
    var amount: Double = 0
    var date: Date = Date.now
    var note: String?

    init(nutrient: Nutrient, amount: Double, date: Date = .now, note: String? = nil) {
        self.nutrient = nutrient
        self.amount = amount
        self.date = date
        self.note = note
    }
}
