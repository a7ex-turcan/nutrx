import Foundation

/// The next dose reminder still to come today, shown on the day-score card ("Vitamin D at 13:00").
struct UpcomingReminder: Equatable {
    let nutrientName: String
    let time: Date

    /// The earliest reminder whose time of day falls strictly after `now`, today.
    /// Only the hour and minute of each `timeOfDay` are used, like the notification scheduler.
    static func next(after now: Date, among candidates: [(nutrientName: String, timeOfDay: Date)],
                     calendar: Calendar = .current) -> UpcomingReminder? {
        candidates
            .compactMap { candidate -> UpcomingReminder? in
                let parts = calendar.dateComponents([.hour, .minute], from: candidate.timeOfDay)
                guard let time = calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0,
                                               second: 0, of: now),
                      time > now else { return nil }
                return UpcomingReminder(nutrientName: candidate.nutrientName, time: time)
            }
            .min { $0.time < $1.time }
    }
}
