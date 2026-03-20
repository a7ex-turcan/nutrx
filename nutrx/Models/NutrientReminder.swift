import Foundation
import SwiftData

@Model
final class NutrientReminder {
    var nutrient: Nutrient?
    var timeOfDay: Date

    init(nutrient: Nutrient, timeOfDay: Date) {
        self.nutrient = nutrient
        self.timeOfDay = timeOfDay
    }

    /// Returns hour and minute components for display and scheduling.
    var timeComponents: (hour: Int, minute: Int) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
        return (hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// Formatted time string (e.g. "9:00 AM").
    var formattedTime: String {
        timeOfDay.formatted(date: .omitted, time: .shortened)
    }
}
