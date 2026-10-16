import Foundation
import SwiftData

enum GoalType: String, Codable, CaseIterable {
    case minimum   // hit at least X — default, matches legacy behaviour
    case maximum   // stay under X
    case range     // stay between dailyTarget (lower) and upperBound (upper)
}

@Model
final class Nutrient {
    var id: UUID = UUID()
    var name: String = ""
    var unit: String = ""
    var step: Double = 1
    var dailyTarget: Double = 0
    var sortOrder: Int = 0
    var isDeleted: Bool = false
    var notes: String? = nil
    var group: NutrientGroup? = nil
    var groupSortOrder: Int = 0
    var createdAt: Date = Date()
    var goalTypeRaw: String = GoalType.minimum.rawValue
    var upperBound: Double? = nil
    var tintRaw: String = ""  // "" = never chosen; `tint` falls back to an id-derived tint
    var symbolName: String = "pills"

    // Supply & refills (nutrx Pro, docs/pro/PLAN.md phase 4). `supplyServings == nil` means supply isn't set.
    /// Units in one serving (one softgel = 1,000 IU); nil means one step ("each tap adds").
    var servingAmount: Double? = nil
    /// Servings in the bottle when it was last refilled.
    var supplyServings: Double? = nil
    /// When the bottle was last refilled; what's logged since then comes out of it.
    var supplyRefilledAt: Date? = nil
    /// Remind when this many days are left.
    var refillReminderDays: Int = 7

    /// The last day of a set course (nutrx Pro, #99), at the start of that day; nil = ongoing. From the next day the
    /// nutrient is off Today, its reminders stop, and History, streaks and analytics count it only up to here.
    var endDate: Date? = nil
    /// The days between a course's end and its restart, so they never count as missed (#99): "start-end" pairs of
    /// start-of-day timestamps, comma-separated (a string, so it's one CloudKit field). Read via `courseGaps`.
    var courseGapsRaw: String = ""

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .minimum }
        set { goalTypeRaw = newValue.rawValue }
    }

    var tint: NutrientTint {
        get { NutrientTint(rawValue: tintRaw) ?? .fallback(for: id) }
        set { tintRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \IntakeRecord.nutrient)
    var intakeRecords: [IntakeRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \Exclusion.nutrient)
    var exclusions: [Exclusion]? = []

    @Relationship(deleteRule: .cascade, inverse: \NutrientReminder.nutrient)
    var reminders: [NutrientReminder]? = []

    /// The stacks this nutrient is in. A deleted (soft-deleted) nutrient keeps its entries, but stacks skip it.
    @Relationship(deleteRule: .cascade, inverse: \LogStackEntry.nutrient)
    var stackEntries: [LogStackEntry]? = []

    init(name: String, unit: String, step: Double, dailyTarget: Double, sortOrder: Int, isDeleted: Bool = false, goalType: GoalType = .minimum, upperBound: Double? = nil) {
        self.name = name
        self.unit = unit
        self.step = step
        self.dailyTarget = dailyTarget
        self.sortOrder = sortOrder
        self.isDeleted = isDeleted
        self.goalTypeRaw = goalType.rawValue
        self.upperBound = upperBound
    }
}

// MARK: - Courses (#99)

/// A course's days, shared by the app, the widgets and the Watch (this file is in every target).
enum NutrientCourse {
    /// The last day of a course of `days` days that starts on `start` ("for 5 days" from Monday ends Friday).
    static func lastDay(days: Int, from start: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: max(1, days) - 1, to: calendar.startOfDay(for: start))!
    }

    /// The days from `start` to `lastDay`, both included (at least 1).
    static func dayCount(from start: Date, to lastDay: Date, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: lastDay)).day ?? 0
        return max(1, days + 1)
    }

    /// Past the last day (the day after it, or later).
    static func hasEnded(_ endDate: Date?, by date: Date, calendar: Calendar = .current) -> Bool {
        guard let endDate else { return false }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: endDate)
    }

    /// Counted on a day: on or before the last day (any day for an ongoing nutrient), and not in a gap between a
    /// course's end and its restart.
    static func includes(_ endDate: Date?, gaps: [ClosedRange<Date>] = [], day: Date,
                         calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: day)
        return !hasEnded(endDate, by: day, calendar: calendar) && !gaps.contains { $0.contains(start) }
    }

    /// The days a restart on `restartDay` skips: from the day after `endDate` to the day before the restart. Nil when
    /// there are none (restarted the day after it ended) or it hadn't ended.
    static func gap(after endDate: Date?, restartingOn restartDay: Date,
                    calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard let endDate, hasEnded(endDate, by: restartDay, calendar: calendar),
              let first = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)),
              let last = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: restartDay)),
              first <= last else { return nil }
        return first...last
    }

    static func encode(_ gaps: [ClosedRange<Date>]) -> String {
        gaps.map { "\(Int($0.lowerBound.timeIntervalSince1970))-\(Int($0.upperBound.timeIntervalSince1970))" }
            .joined(separator: ",")
    }

    static func decode(_ raw: String) -> [ClosedRange<Date>] {
        raw.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: "-").compactMap { TimeInterval($0) }
            guard parts.count == 2, parts[0] <= parts[1] else { return nil }
            return Date(timeIntervalSince1970: parts[0])...Date(timeIntervalSince1970: parts[1])
        }
    }
}

extension Nutrient {
    /// Past the last day of its course.
    func hasEnded(by date: Date = .now, calendar: Calendar = .current) -> Bool {
        NutrientCourse.hasEnded(endDate, by: date, calendar: calendar)
    }

    /// On Today (and the widgets, the Watch, reminders, stacks and Siri) on this day: not deleted and not ended.
    func isRunning(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        !isDeleted && !hasEnded(by: date, calendar: calendar)
    }

    var courseGaps: [ClosedRange<Date>] { NutrientCourse.decode(courseGapsRaw) }

    /// Sets a new last day (nil = ongoing). If the course had ended, the days since then are kept as a gap, so
    /// restarting never turns them into misses after the fact. The one writer of `endDate` for a saved nutrient.
    func setCourse(endDate newEndDate: Date?, now: Date = .now, calendar: Calendar = .current) {
        guard newEndDate != endDate else { return }
        if let gap = NutrientCourse.gap(after: endDate, restartingOn: now, calendar: calendar) {
            courseGapsRaw = NutrientCourse.encode(courseGaps + [gap])
        }
        endDate = newEndDate
    }
}
