import Foundation

/// Which dose-reminder notifications to have pending, as one-off requests per date (#4).
///
/// Each reminder time is scheduled for each of the next `days` days, starting today. Today's times that have
/// passed are left out, and so is the rest of today for a nutrient already logged today: logging silences only
/// today, never the following days. The window rolls forward every time the app reschedules (foreground, and
/// after any log or reminder change), and it's sized so all requests stay under iOS's 64 pending
/// notifications (the daily check-in takes one more).
enum ReminderSchedule {
    /// A reminder's time of day.
    struct Time: Equatable {
        let hour: Int
        let minute: Int
    }

    /// A nutrient's reminders as the scheduler sees them.
    struct Plan: Equatable {
        let nutrientID: UUID
        let times: [Time]
        /// Today's total is above zero: no more reminders for it today.
        let loggedToday: Bool
    }

    /// One pending notification: its identifier and when it fires.
    struct Occurrence: Equatable {
        let nutrientID: UUID
        let id: String
        let fireDate: Date
    }

    /// Requests left for dose reminders under iOS's 64-pending limit, keeping room for the daily check-in.
    static let budget = 60
    /// The longest window, for someone with few reminders.
    static let maxDays = 14

    /// Days to schedule ahead so `reminderCount` reminders a day fit the budget; at least today.
    static func days(forReminderCount reminderCount: Int) -> Int {
        guard reminderCount > 0 else { return 0 }
        return min(maxDays, max(1, budget / reminderCount))
    }

    /// Every occurrence to have pending for these plans, from `now`.
    static func occurrences(for plans: [Plan], now: Date, calendar: Calendar = .current) -> [Occurrence] {
        let days = days(forReminderCount: plans.reduce(0) { $0 + $1.times.count })
        let today = calendar.startOfDay(for: now)
        return plans.flatMap { plan in
            (0..<days).flatMap { offset -> [Occurrence] in
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return [] }
                if offset == 0 && plan.loggedToday { return [] }
                return plan.times.compactMap { time in
                    guard let fireDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0,
                                                       of: day),
                          fireDate > now else { return nil }
                    return Occurrence(nutrientID: plan.nutrientID,
                                      id: identifier(nutrientID: plan.nutrientID, hour: time.hour,
                                                     minute: time.minute, day: day, calendar: calendar),
                                      fireDate: fireDate)
                }
            }
        }
    }

    /// Every request of one nutrient starts with this (also the old repeating requests' prefix).
    static func prefix(nutrientID: UUID) -> String {
        "nutrient-\(nutrientID.uuidString)-reminder-"
    }

    /// "nutrient-<uuid>-reminder-0900-20261013": the time, then the date it's for.
    static func identifier(nutrientID: UUID, hour: Int, minute: Int, day: Date, calendar: Calendar = .current)
        -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let date = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "\(prefix(nutrientID: nutrientID))\(String(format: "%02d%02d", hour, minute))-\(date)"
    }
}
