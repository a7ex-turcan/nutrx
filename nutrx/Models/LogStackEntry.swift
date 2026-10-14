import Foundation
import SwiftData

/// One nutrient in a `LogStack` and the amount the stack logs for it (in the nutrient's unit; starts at its step).
@Model
final class LogStackEntry {
    var amount: Double = 0
    var sortOrder: Int = 0
    var stack: LogStack? = nil
    var nutrient: Nutrient? = nil

    init(nutrient: Nutrient, amount: Double, sortOrder: Int) {
        self.nutrient = nutrient
        self.amount = amount
        self.sortOrder = sortOrder
    }
}
