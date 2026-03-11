import Foundation
import SwiftData

@Model
final class IntakeRecord: @unchecked Sendable {
    var nutrient: Nutrient?
    var amount: Double
    var date: Date

    init(nutrient: Nutrient, amount: Double, date: Date = .now) {
        self.nutrient = nutrient
        self.amount = amount
        self.date = date
    }
}
