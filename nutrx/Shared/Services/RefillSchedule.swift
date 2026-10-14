import Foundation

/// When to send a supply refill reminder (nutrx Pro, docs/pro/PLAN.md phase 4), kept pure for tests
/// (`RefillScheduleTests`). One reminder per bottle:
///
/// - at 10:00 on the day the estimate reaches the reminder threshold ("Remind me at 7 days left");
/// - if it's already at or under it (or out), at the next 10:00;
/// - never again for the same bottle once it has fired, unless "Remind me tomorrow" snoozed it;
/// - nothing without a days-left estimate (and not out), or once refilled (a new bottle starts over).
///
/// What has fired is remembered on this device (`State`), not synced: a reminder per bottle per device.
enum RefillSchedule {
    static let hour = 10

    /// What this device has scheduled for one bottle.
    struct State: Codable, Equatable {
        /// The bottle: the refill date it belongs to.
        let refilledAt: Date
        /// When it fires (or fired).
        let fireDate: Date
        /// Set by "Remind me tomorrow": keep this date rather than recomputing it.
        var snoozed: Bool = false
    }

    /// The fire date for a bottle now, given what was scheduled before; nil means no reminder pending.
    static func fireDate(status: SupplySchedule.Status, previous: State?, now: Date,
                         calendar: Calendar = .current) -> Date? {
        let bottle = status.setup.refilledAt
        if let previous, previous.refilledAt == bottle {
            if previous.fireDate <= now { return nil }  // already fired for this bottle
            if previous.snoozed { return previous.fireDate }
        }
        let daysUntil: Int
        switch status.level {
        case .out:
            daysUntil = 0
        case .noHistory:
            return nil
        case .low, .plenty:
            guard let daysLeft = status.daysLeft else { return nil }
            daysUntil = max(0, daysLeft - status.setup.reminderDays)
        }
        return nextReminderTime(inDays: daysUntil, now: now, calendar: calendar)
    }

    /// 10:00 `days` days from today, or the next 10:00 when that has passed.
    static func nextReminderTime(inDays days: Int, now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .day, value: days, to: today),
              var fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return nil }
        if fire <= now, let next = calendar.date(byAdding: .day, value: 1, to: fire) {
            fire = next
        }
        return fire
    }

    /// "Remind me tomorrow": 24 hours from now.
    static func snoozed(_ status: SupplySchedule.Status, now: Date) -> State {
        State(refilledAt: status.setup.refilledAt, fireDate: now.addingTimeInterval(24 * 60 * 60), snoozed: true)
    }

    /// Days left on the day it fires: the threshold when it fires on the crossing day, today's estimate when it
    /// fires at the next 10:00 (minus the day in between).
    static func daysAtFire(status: SupplySchedule.Status, fireDate: Date, now: Date,
                           calendar: Calendar = .current) -> Int? {
        guard let daysLeft = status.daysLeft else { return nil }
        let wait = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: fireDate)).day ?? 0
        return max(0, daysLeft - wait)
    }

    /// "Vitamin D runs out in about a week" / "… in about 3 days" / "… tomorrow" / "… today" / "Vitamin D has
    /// run out".
    static func title(name: String, daysAtFire: Int?, isOut: Bool) -> String {
        if isOut { return "\(name) has run out" }
        switch daysAtFire ?? 0 {
        case ...0: return "\(name) runs out today"
        case 1: return "\(name) runs out tomorrow"
        case 6...8: return "\(name) runs out in about a week"
        case let days: return "\(name) runs out in about \(days) days"
        }
    }

    /// "About 7 days left at your usual amount. Tap Refilled when you open a new bottle."
    static func body(daysAtFire: Int?, isOut: Bool) -> String {
        let tail = "Tap Refilled when you open a new bottle."
        if isOut { return "Out of supply. \(tail)" }
        guard let days = daysAtFire else { return tail }
        let left = days <= 0 ? "Less than a day left" : days == 1 ? "About 1 day left" : "About \(days) days left"
        return "\(left) at your usual amount. \(tail)"
    }

    static let identifierPrefix = "refill-"

    static func identifier(nutrientID: UUID) -> String {
        identifier(forKey: nutrientID.uuidString)
    }

    /// The request identifier for a record key (a nutrient id string).
    static func identifier(forKey key: String) -> String {
        "\(identifierPrefix)\(key)"
    }
}
