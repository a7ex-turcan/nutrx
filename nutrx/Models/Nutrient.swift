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
    /// Soft delete: off Today and My Nutrients, kept for history.
    var isRemoved: Bool = false
    /// The old soft-delete flag. Never set it or read it outside `ModelContainerFactory.copyLegacyRemovals`, which
    /// copies it into `isRemoved` once per device. Its name is also `NSManagedObject`'s own `isDeleted`, so Core Data
    /// read the stored value by name as false: iCloud sync brought removed nutrients back, and the flag could read
    /// false right after a save (#56). It stays because a CloudKit store can't rename a property.
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
    /// The days between a course's end and its restart, so they never count as missed (#99): "yyyyMMdd-yyyyMMdd"
    /// pairs, comma-separated (a string, so it's one CloudKit field). Read via `courseGaps(calendar:)`.
    var courseGapsRaw: String = ""
    /// Which days it's taken on when not every day (nutrx Pro, #132, docs/pro/SCHEDULES.md): pieces of
    /// "yyyyMMdd=kind", each in effect from its day, ";"-separated; "" = every day. Read via `schedule(calendar:)`.
    var scheduleRaw: String = ""

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

    init(name: String, unit: String, step: Double, dailyTarget: Double, sortOrder: Int, isRemoved: Bool = false, goalType: GoalType = .minimum, upperBound: Double? = nil) {
        self.name = name
        self.unit = unit
        self.step = step
        self.dailyTarget = dailyTarget
        self.sortOrder = sortOrder
        self.isRemoved = isRemoved
        self.goalTypeRaw = goalType.rawValue
        self.upperBound = upperBound
    }
}

// MARK: - Calendar days in stored strings

/// A calendar day as "yyyyMMdd", rebuilt in the reading calendar, so a time zone change never moves it (course gaps,
/// schedules).
nonisolated private enum StoredDay {
    static func string(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(_ text: Substring, calendar: Calendar) -> Date? {
        guard text.count == 8, let value = Int(text) else { return nil }
        let parts = DateComponents(year: value / 10000, month: value / 100 % 100, day: value % 100)
        return calendar.date(from: parts).map { calendar.startOfDay(for: $0) }
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

    /// The course's last day is `date`'s day (Today's "Last day" line, #128). Never for an ongoing nutrient.
    static func isLastDay(_ endDate: Date?, on date: Date, calendar: Calendar = .current) -> Bool {
        guard let endDate else { return false }
        return calendar.isDate(endDate, inSameDayAs: date)
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

    /// Gaps are calendar days, stored as "yyyyMMdd-yyyyMMdd" pairs and rebuilt in the reading calendar, so a time
    /// zone change never shifts a paused day back into a miss.
    static func encode(_ gaps: [ClosedRange<Date>], calendar: Calendar = .current) -> String {
        gaps.map { "\(StoredDay.string($0.lowerBound, calendar: calendar))-\(StoredDay.string($0.upperBound, calendar: calendar))" }
            .joined(separator: ",")
    }

    static func decode(_ raw: String, calendar: Calendar = .current) -> [ClosedRange<Date>] {
        raw.split(separator: ",").compactMap { pair in
            let days = pair.split(separator: "-").compactMap { StoredDay.date($0, calendar: calendar) }
            guard days.count == 2, days[0] <= days[1] else { return nil }
            return days[0]...days[1]
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
        !isRemoved && !hasEnded(by: date, calendar: calendar)
    }

    /// Read in the same calendar the caller matches days in.
    func courseGaps(calendar: Calendar = .current) -> [ClosedRange<Date>] {
        NutrientCourse.decode(courseGapsRaw, calendar: calendar)
    }

    /// Sets a new last day (nil = ongoing). If the course had ended, the days since then are kept as a gap, so
    /// restarting never turns them into misses after the fact. The one writer of `endDate` for a saved nutrient.
    func setCourse(endDate newEndDate: Date?, now: Date = .now, calendar: Calendar = .current) {
        guard newEndDate != endDate else { return }
        if let gap = NutrientCourse.gap(after: endDate, restartingOn: now, calendar: calendar) {
            let gaps = courseGaps(calendar: calendar) + [gap]
            courseGapsRaw = NutrientCourse.encode(gaps, calendar: calendar)
        }
        endDate = newEndDate
    }
}

// MARK: - Schedules (#132)

/// Which days a nutrient is taken on when it isn't every day (nutrx Pro, docs/pro/SCHEDULES.md), shared by the app,
/// the widgets and the Watch. A schedule is a list of pieces, each in effect from its day until the next one, so
/// changing it never rewrites the days before; days before the first piece are every day.
nonisolated struct NutrientSchedule: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case everyDay
        /// On these weekdays, `Calendar` numbers (1 = Sunday, 2 = Monday).
        case weekdays(Set<Int>)
        /// `on` days on, then `off` days off, repeating from `start` (a start of day); not due before `start`.
        /// "Every 3 days" is 1 on, 2 off.
        case cycle(on: Int, off: Int, start: Date)
        /// Any `times` days a week, Monday to Sunday: the daily goal met on that many days.
        case weekly(times: Int)
    }

    struct Piece: Equatable, Sendable {
        /// The first day it's in effect (a start of day).
        let from: Date
        let kind: Kind
    }

    /// "1 of 3 this week".
    struct WeekProgress: Equatable, Sendable {
        let met: Int
        let times: Int
        var isDone: Bool { met >= times }
    }

    /// What the sheet offers: 7 a week is every day.
    static let timesAWeek = 1...6
    static let cycleLengths = 1...60

    /// Oldest first.
    private(set) var pieces: [Piece] = []

    /// The kind in effect on `day`.
    func kind(on day: Date, calendar: Calendar = .current) -> Kind {
        let start = calendar.startOfDay(for: day)
        return pieces.last { $0.from <= start }?.kind ?? .everyDay
    }

    /// Due on `day`: every day, one of its weekdays, or an "on" day of its cycle. Under a weekly schedule any day can
    /// be one, until the week's count is reached; only the caller knows the met days (`weekProgress`).
    func isDoseDay(_ day: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: day)
        switch kind(on: start, calendar: calendar) {
        case .everyDay, .weekly:
            return true
        case .weekdays(let weekdays):
            return weekdays.contains(calendar.component(.weekday, from: start))
        case .cycle(let on, let off, let cycleStart):
            // A cycle built in code isn't checked like a decoded one; never divide by zero.
            guard on > 0, off >= 0, start >= cycleStart,
                  let offset = calendar.dateComponents([.day], from: cycleStart, to: start).day else { return false }
            return offset % (on + off) < on
        }
    }

    /// The weekly count in effect on `day`, or nil when it isn't under a weekly schedule.
    func weeklyTimes(on day: Date, calendar: Calendar = .current) -> Int? {
        if case .weekly(let times) = kind(on: day, calendar: calendar) { return times }
        return nil
    }

    /// Monday of `day`'s week: the same weeks as the weekly recap (`WeeklyRecap.weekStart`).
    static func weekStart(of day: Date, calendar: Calendar = .current) -> Date {
        var monday = calendar
        monday.firstWeekday = 2
        return monday.dateInterval(of: .weekOfYear, for: day)?.start ?? calendar.startOfDay(for: day)
    }

    /// The met days that count under a weekly schedule: in each week, the first `times` of them. Later met days that
    /// week don't count, and days under another kind are left out (the caller counts those as usual).
    func weeklyCountedDays(_ metDays: some Sequence<Date>, calendar: Calendar = .current) -> Set<Date> {
        var usedInWeek: [Date: Int] = [:]
        var counted = Set<Date>()
        for day in Set(metDays.map { calendar.startOfDay(for: $0) }).sorted() {
            guard let times = weeklyTimes(on: day, calendar: calendar) else { continue }
            let week = Self.weekStart(of: day, calendar: calendar)
            guard usedInWeek[week, default: 0] < times else { continue }
            usedInWeek[week, default: 0] += 1
            counted.insert(day)
        }
        return counted
    }

    /// "1 of 3 this week" for `day`'s week, from the days the goal was met; nil when `day` isn't under a weekly
    /// schedule.
    func weekProgress(on day: Date, metDays: some Sequence<Date>, calendar: Calendar = .current) -> WeekProgress? {
        guard let times = weeklyTimes(on: day, calendar: calendar) else { return nil }
        let week = Self.weekStart(of: day, calendar: calendar)
        let met = weeklyCountedDays(metDays, calendar: calendar)
            .filter { Self.weekStart(of: $0, calendar: calendar) == week }.count
        return WeekProgress(met: met, times: times)
    }

    /// The whole week from `monday` is under one weekly schedule. A week only partly under it isn't judged as met or
    /// missed; the caller also checks the nutrient's creation day and course.
    func isWholeWeekly(weekStarting monday: Date, calendar: Calendar = .current) -> Bool {
        let kinds = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
            .map { kind(on: $0, calendar: calendar) }
        guard let first = kinds.first, case .weekly = first else { return false }
        return kinds.allSatisfy { $0 == first }
    }

    /// This schedule with `kind` in effect from `day` on. A piece already starting on or after `day` is replaced (a
    /// change made the same day), and nothing is added when `kind` is already in effect.
    func setting(_ kind: Kind, from day: Date, calendar: Calendar = .current) -> NutrientSchedule {
        let start = calendar.startOfDay(for: day)
        var schedule = self
        schedule.pieces.removeAll { $0.from >= start }
        if schedule.kind(on: start, calendar: calendar) != kind {
            schedule.pieces.append(Piece(from: start, kind: kind))
        }
        return schedule
    }

    // MARK: Stored form

    /// "yyyyMMdd=kind" pieces, ";"-separated: "20261023=days:2,4,6", "…=cycle:5:2:20261023", "…=week:3", "…=daily".
    func encode(calendar: Calendar = .current) -> String {
        pieces.map { piece in
            let kind: String
            switch piece.kind {
            case .everyDay: kind = "daily"
            case .weekdays(let weekdays): kind = "days:" + weekdays.sorted().map(String.init).joined(separator: ",")
            case .cycle(let on, let off, let start):
                kind = "cycle:\(on):\(off):" + StoredDay.string(start, calendar: calendar)
            case .weekly(let times): kind = "week:\(times)"
            }
            return StoredDay.string(piece.from, calendar: calendar) + "=" + kind
        }
        .joined(separator: ";")
    }

    /// Pieces it can't read are skipped, so a damaged field falls back towards every day rather than failing.
    static func decode(_ raw: String, calendar: Calendar = .current) -> NutrientSchedule {
        var schedule = NutrientSchedule()
        schedule.pieces = raw.split(separator: ";").compactMap { text in
            let halves = text.split(separator: "=", maxSplits: 1)
            guard halves.count == 2, let from = StoredDay.date(halves[0], calendar: calendar),
                  let kind = kind(halves[1], calendar: calendar) else { return nil }
            return Piece(from: from, kind: kind)
        }
        .sorted { $0.from < $1.from }
        return schedule
    }

    private static func kind(_ text: Substring, calendar: Calendar) -> Kind? {
        let parts = text.split(separator: ":")
        guard let head = parts.first else { return nil }
        switch head {
        case "daily" where parts.count == 1:
            return .everyDay
        case "days" where parts.count == 2:
            let weekdays = Set(parts[1].split(separator: ",").compactMap { Int($0) })
            guard !weekdays.isEmpty, weekdays.allSatisfy((1...7).contains) else { return nil }
            return .weekdays(weekdays)
        case "cycle" where parts.count == 4:
            guard let on = Int(parts[1]), let off = Int(parts[2]), cycleLengths.contains(on), cycleLengths.contains(off),
                  let start = StoredDay.date(parts[3], calendar: calendar) else { return nil }
            return .cycle(on: on, off: off, start: start)
        case "week" where parts.count == 2:
            guard let times = Int(parts[1]), timesAWeek.contains(times) else { return nil }
            return .weekly(times: times)
        default:
            return nil
        }
    }
}

extension Nutrient {
    /// Read in the same calendar the caller matches days in.
    func schedule(calendar: Calendar = .current) -> NutrientSchedule {
        NutrientSchedule.decode(scheduleRaw, calendar: calendar)
    }

    /// Counted on `day` by the daily rules (History, streaks, analytics, reminders): its course includes the day and
    /// its schedule makes it a dose day. Never under a weekly schedule: there a day counts only once met, among the
    /// week's first few (`NutrientSchedule.weeklyCountedDays`), which needs the met days only the caller has. So the
    /// safe default is "not counted", and an unmet weekly day never reads as a miss.
    func counts(on day: Date, calendar: Calendar = .current) -> Bool {
        let schedule = self.schedule(calendar: calendar)
        return NutrientCourse.includes(endDate, gaps: courseGaps(calendar: calendar), day: day, calendar: calendar)
            && schedule.weeklyTimes(on: day, calendar: calendar) == nil
            && schedule.isDoseDay(day, calendar: calendar)
    }

    /// On Today's list (and the widgets', the Watch's and stacks') on `day`: running and due. `weekDone` is whether a
    /// weekly schedule's count was reached before `day`, from the caller's met days; on the day it's reached the
    /// nutrient stays, as Done. `isRunning` itself knows nothing of schedules, so Siri still sees every nutrient.
    func isDue(on day: Date = .now, weekDone: Bool = false, calendar: Calendar = .current) -> Bool {
        isRunning(on: day, calendar: calendar) && schedule(calendar: calendar).isDoseDay(day, calendar: calendar)
            && !weekDone
    }
}
