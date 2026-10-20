import Foundation
import SwiftData

@Model
final class NutrientReminder {
    var nutrient: Nutrient?
    var timeOfDay: Date = Date.distantPast

    init(nutrient: Nutrient, timeOfDay: Date) {
        self.nutrient = nutrient
        self.timeOfDay = timeOfDay
    }

    /// Returns hour and minute components for display and scheduling.
    var timeComponents: (hour: Int, minute: Int) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
        return (hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// Whether one of `reminders` is already at this hour and minute (the reminders sheet refuses a duplicate, #163).
    static func hasReminder(at time: Date, among reminders: [NutrientReminder], calendar: Calendar = .current) -> Bool {
        let wanted = calendar.dateComponents([.hour, .minute], from: time)
        return reminders.contains {
            let parts = calendar.dateComponents([.hour, .minute], from: $0.timeOfDay)
            return parts.hour == wanted.hour && parts.minute == wanted.minute
        }
    }

    /// Formatted time string (e.g. "9:00 AM").
    var formattedTime: String {
        timeOfDay.formatted(date: .omitted, time: .shortened)
    }
}
