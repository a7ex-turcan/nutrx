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
    /// What one bottle (the supply above) costs, in the user's currency; nil = no price (#134,
    /// docs/pro/SUPPLY-COSTS.md). Only the number is stored: no currency, no conversion.
    var supplyPrice: Double? = nil

    /// The last day of a set course (nutrx Pro, #99), at the start of that day; nil = ongoing. From the next day the
    /// nutrient is off Today, its reminders stop, and History, streaks and analytics count it only up to here.
    var endDate: Date? = nil
    /// The days between a course's end and its restart, so they never count as missed (#99): "yyyyMMdd-yyyyMMdd"
    /// pairs, comma-separated (a string, so it's one CloudKit field). Read via `courseGaps(calendar:)`.
    var courseGapsRaw: String = ""
    /// Which days it's taken on when not every day (nutrx Pro, #132, docs/pro/SCHEDULES.md): pieces of
    /// "yyyyMMdd=kind", each in effect from its day, ";"-separated; "" = every day. Read via `schedule(calendar:)`.
    var scheduleRaw: String = ""
    /// Reminders at the usual time instead of set times (nutrx Pro, #137, docs/pro/REMINDERS.md §3): -1 = at the set
    /// times; 0 or more = one reminder a day at the learned time (`UsualTime`), with this starting time (minutes after
    /// midnight) until it's learned, around midnight and without Pro. The set times are kept for switching back.
    var usualReminderMinutes: Int = -1
    /// A goal that follows steps (nutrx Pro, #135, docs/pro/DOSE-PLANS.md): the plan and the goals it gave past days,
    /// read via `dosePlan(calendar:)`; "" = never had one.
    var dosePlanRaw: String = ""
    /// The last day a device knew Pro was active with this plan ("yyyyMMdd", docs/pro/DOSE-PLANS.md §6): a device
    /// without Pro holds the plan only when it's more than a day old. Its own field, so writing it never rewrites
    /// the plan. Nothing reads it to unlock anything.
    var dosePlanSeenWithPro: String = ""

    var remindsAtUsualTime: Bool { usualReminderMinutes >= 0 }

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
/// schedules, dose plans).
nonisolated enum StoredDay {
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

    /// A day the daily rules count (History, streaks, analytics): a dose day under every day or a fixed kind. Never
    /// under a weekly schedule, where a day counts only once met (`weeklyCountedDays`), which the caller works out.
    func isCountedDay(_ day: Date, calendar: Calendar = .current) -> Bool {
        weeklyTimes(on: day, calendar: calendar) == nil && isDoseDay(day, calendar: calendar)
    }

    /// The first dose day after `day`, up to a year ahead (Today's Not today line).
    func nextDoseDay(after day: Date, calendar: Calendar = .current) -> Date? {
        var date = calendar.startOfDay(for: day)
        for _ in 0..<366 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            date = next
            if isDoseDay(date, calendar: calendar) { return date }
        }
        return nil
    }

    /// Any piece is a weekly schedule: the callers then work out its counted days (`weeklyCountedDays`).
    var hasWeekly: Bool {
        pieces.contains { if case .weekly = $0.kind { true } else { false } }
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
        NutrientCourse.includes(endDate, gaps: courseGaps(calendar: calendar), day: day, calendar: calendar)
            && schedule(calendar: calendar).isCountedDay(day, calendar: calendar)
    }

    /// The next day it's due after `day`, or nil when its course is over first (Today's Not today line). A weekly
    /// schedule whose count is reached is due again next Monday.
    func nextDueDay(after day: Date, calendar: Calendar = .current) -> Date? {
        let next: Date?
        if weekProgress(including: day, calendar: calendar)?.isDone == true {
            next = calendar.date(byAdding: .day, value: 7, to: NutrientSchedule.weekStart(of: day, calendar: calendar))
        } else {
            next = schedule(calendar: calendar).nextDoseDay(after: day, calendar: calendar)
        }
        guard let next, !hasEnded(by: next, calendar: calendar) else { return nil }
        return next
    }

    /// Under a weekly schedule (#132): the counted days of `day`'s week (those before it, or through it with
    /// `including`) and the count. Nil when `day` isn't under one. Read from its own logs, so Today, stacks, the
    /// widgets, the Watch and reminders agree.
    func weekProgress(before day: Date, calendar: Calendar = .current) -> NutrientSchedule.WeekProgress? {
        weekProgress(of: day, throughDay: false, calendar: calendar)
    }

    func weekProgress(including day: Date, calendar: Calendar = .current) -> NutrientSchedule.WeekProgress? {
        weekProgress(of: day, throughDay: true, calendar: calendar)
    }

    private func weekProgress(of day: Date, throughDay: Bool, calendar: Calendar) -> NutrientSchedule.WeekProgress? {
        let schedule = self.schedule(calendar: calendar)
        let start = calendar.startOfDay(for: day)
        guard schedule.weeklyTimes(on: start, calendar: calendar) != nil,
              let end = calendar.date(byAdding: .day, value: throughDay ? 1 : 0, to: start) else { return nil }
        let monday = NutrientSchedule.weekStart(of: start, calendar: calendar)
        var totals: [Date: Double] = [:]
        for record in records(from: monday, to: end) {
            totals[calendar.startOfDay(for: record.date), default: 0] += record.amount
        }
        let gaps = courseGaps(calendar: calendar)
        let plan = dosePlan(calendar: calendar)  // each day's own goal (#135), decoded once
        let metDays = totals.compactMap { date, total -> Date? in
            GoalProgress(nutrient: self, current: max(0, total),
                         goal: plan.goal(on: date, calendar: calendar) ?? baseGoal).countsAsMet
                && NutrientCourse.includes(endDate, gaps: gaps, day: date, calendar: calendar) ? date : nil
        }
        return schedule.weekProgress(on: start, metDays: metDays, calendar: calendar)
    }

    /// Its records from `start` up to `end`, fetched by date when it's in a store, so reading one week doesn't load
    /// years of history (#249: a Today refresh, the widgets, the Watch and stacks all ask; supply too, #138);
    /// otherwise the relationship.
    func records(from start: Date, to end: Date) -> [IntakeRecord] {
        if let modelContext {
            let id = self.id
            let descriptor = FetchDescriptor<IntakeRecord>(predicate: #Predicate {
                $0.nutrient?.id == id && $0.date >= start && $0.date < end
            })
            if let records = try? modelContext.fetch(descriptor) { return records }
        }
        return (intakeRecords ?? []).filter { $0.date >= start && $0.date < end }
    }

    /// On Today's list (and the widgets', the Watch's and stacks') on `day`: running and due. A weekly schedule
    /// whose count was reached before `day` isn't due again until Monday; on the day it's reached the nutrient stays,
    /// as Done. `isRunning` itself knows nothing of schedules, so Siri still sees every nutrient.
    func isDue(on day: Date = .now, calendar: Calendar = .current) -> Bool {
        isRunning(on: day, calendar: calendar) && schedule(calendar: calendar).isDoseDay(day, calendar: calendar)
            && weekProgress(before: day, calendar: calendar)?.isDone != true
    }
}

// MARK: - Dose plans (#135)

/// A day's goal: the target (an "at least" amount, an "at most" limit, a range's minimum) and a range's maximum.
nonisolated struct NutrientGoal: Equatable, Sendable {
    var target: Double
    var upperBound: Double? = nil
}

/// A goal that follows steps the user sets (nutrx Pro, docs/pro/DOSE-PLANS.md), shared by the app, the widgets and
/// the Watch: "200 mg for a week, then 400 mg, and keep it", or a taper that stops. Past days keep the goal they had
/// (§3): creating a plan pins the days before it to the base goal, and what a plan gave before it was edited or
/// removed is frozen as pieces, each from its day. Tested in `NutrientDosePlanTests`.
nonisolated struct NutrientDosePlan: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        var goal: NutrientGoal
        /// 1–90 (`stepDays`).
        var days: Int
    }

    /// After the last step: keep its goal, or stop (the nutrient's course ends on the last step's last day).
    enum End: String, Equatable, Sendable { case keep, stop }

    /// The plan in effect from `appliesFrom`.
    struct Plan: Equatable, Sendable {
        /// The first step's first day (a start of day).
        var start: Date
        var steps: [Step]
        var end: End
        /// Days from this one (a start of day) follow the plan; earlier ones are in `history`.
        var appliesFrom: Date
        /// Held without Pro from this day (§6): from it on, the goal stays at the step in effect that day.
        var heldFrom: Date? = nil
    }

    /// A frozen goal, from its day until the next piece or the plan. A nil goal is the base goal, as it is then.
    struct Piece: Equatable, Sendable {
        /// A start of day, or `.distantPast` for "from the start of the nutrient's history".
        let from: Date
        let goal: NutrientGoal?
    }

    /// Where a day falls in the plan, for "Step 2 of 3 · until Fri".
    struct Position: Equatable, Sendable {
        /// From 1.
        let step: Int
        let count: Int
        /// The step's last day.
        let lastDay: Date
    }

    static let stepCounts = 2...6
    static let stepDays = 1...90

    /// Oldest first.
    private(set) var history: [Piece] = []
    /// The plan in effect, or nil when there's none (never had one, or removed; its past stays in `history`).
    private(set) var plan: Plan?

    /// The plan's goal on `day`, or nil for the base goal (no plan, before its start, or after it was removed).
    func goal(on day: Date, calendar: Calendar = .current) -> NutrientGoal? {
        let start = calendar.startOfDay(for: day)
        if let plan, start >= plan.appliesFrom { return Self.goal(of: plan, on: start, calendar: calendar) }
        return history.last { $0.from <= start }?.goal
    }

    /// Where `day` falls in the plan's steps; nil outside them (before the start, after the last step), with no plan
    /// in effect that day, and while held, when the steps aren't moving.
    func position(on day: Date, calendar: Calendar = .current) -> Position? {
        let start = calendar.startOfDay(for: day)
        guard let plan, start >= plan.appliesFrom, !isHeld(on: start, calendar: calendar),
              let index = Self.stepIndex(of: plan, on: start, calendar: calendar) else { return nil }
        return Position(step: index + 1, count: plan.steps.count,
                        lastDay: Self.lastDay(ofStep: index, in: plan, calendar: calendar))
    }

    /// Held without Pro on `day`.
    func isHeld(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let heldFrom = plan?.heldFrom else { return false }
        return calendar.startOfDay(for: day) >= heldFrom
    }

    /// A plan that stops: its last step's last day, the course's end (nil while held, or for one that keeps).
    func stopDay(calendar: Calendar = .current) -> Date? {
        guard let plan, plan.end == .stop, plan.heldFrom == nil, !plan.steps.isEmpty else { return nil }
        return Self.lastDay(ofStep: plan.steps.count - 1, in: plan, calendar: calendar)
    }

    /// Still moving on `day`: not started yet, or within its steps. A plan keeping its last goal, or past its stop
    /// day, is settled: holding it would change nothing.
    func isMoving(on day: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: day)
        guard let plan, start >= plan.appliesFrom else { return false }
        return start < plan.start || Self.stepIndex(of: plan, on: start, calendar: calendar) != nil
    }

    // MARK: Changes

    /// A new plan, from `start` (today or later). The days before it are pinned to the goal they have now (the base
    /// goal, or what an earlier plan left), so neither a later change to the base goal nor removing this plan
    /// re-judges them.
    func creating(steps: [Step], end: End, start: Date, base: NutrientGoal, today: Date,
                  calendar: Calendar = .current) -> NutrientDosePlan {
        let day = calendar.startOfDay(for: today)
        var result = frozen(through: day, base: base, calendar: calendar)
        // Days since an earlier plan was removed were judged by this base goal: pin them to it too.
        result.history = result.history.map { $0.goal == nil ? Piece(from: $0.from, goal: base) : $0 }
        if result.history.isEmpty { result.history.append(Piece(from: .distantPast, goal: base)) }
        result.plan = Plan(start: max(calendar.startOfDay(for: start), day), steps: steps, end: end, appliesFrom: day)
        return result
    }

    /// The plan with new steps or a new end, from `today`: the days before keep what the plan gave them.
    func editing(steps: [Step], end: End, today: Date, calendar: Calendar = .current) -> NutrientDosePlan {
        guard let plan else { return self }
        let day = calendar.startOfDay(for: today)
        var result = frozen(through: day, base: nil, calendar: calendar)
        result.plan = Plan(start: plan.start, steps: steps, end: end, appliesFrom: day, heldFrom: nil)
        return result
    }

    /// No plan from `today`; the days before keep what it gave them. The goal the base should take from today, so
    /// nothing jumps (§3, §6): a kept last goal, or the held goal; nil to keep the base goal as it is.
    func removing(today: Date, calendar: Calendar = .current) -> (plan: NutrientDosePlan, newBase: NutrientGoal?) {
        guard let plan else { return (self, nil) }
        let day = calendar.startOfDay(for: today)
        let newBase = day >= plan.appliesFrom ? plan.goalIfRemoved(on: day, calendar: calendar) : nil
        var result = frozen(through: day, base: nil, calendar: calendar)
        result.plan = nil
        result.history.append(Piece(from: day, goal: nil))
        return (result, newBase)
    }

    /// The base goal is about to change from `today`: its pieces before today keep `oldBase`, the value they were
    /// judged by, and the new base applies from today (§3).
    func pinningBase(_ oldBase: NutrientGoal, today: Date, calendar: Calendar = .current) -> NutrientDosePlan {
        guard !history.isEmpty else { return self }
        let day = calendar.startOfDay(for: today)
        // A plan not started yet gave its days so far the base goal: freeze them with the old one first.
        var result = frozen(through: day, base: oldBase, calendar: calendar)
        result.history = result.history.map { $0.goal == nil && $0.from < day ? Piece(from: $0.from, goal: oldBase) : $0 }
        if let appliesFrom = result.plan?.appliesFrom {
            result.plan?.appliesFrom = max(appliesFrom, day)
        } else {
            result.history.removeAll { $0.from >= day }
            result.history.append(Piece(from: day, goal: nil))
        }
        return result
    }

    /// What the form's Save does (§3, §5): the plan as set there (`setup`, nil for none) from `today`. A base goal
    /// that changes once a plan has existed is pinned first; then the plan is created, edited or removed. A saved plan
    /// that hasn't started yet takes a new start (nothing was judged by it). Returns the goal the base should take, for
    /// a removed plan that was keeping or holding its goal, else nil.
    func applying(_ setup: Plan?, oldBase: NutrientGoal, newBase: NutrientGoal, today: Date,
                  calendar: Calendar = .current) -> (plan: NutrientDosePlan, newBase: NutrientGoal?) {
        let day = calendar.startOfDay(for: today)
        var result = self
        if newBase != oldBase, !history.isEmpty || plan != nil {
            result = result.pinningBase(oldBase, today: day, calendar: calendar)
        }
        switch (result.plan, setup) {
        case (nil, let setup?):
            return (result.creating(steps: setup.steps, end: setup.end, start: setup.start, base: newBase, today: day,
                                    calendar: calendar), nil)
        case (let current?, let setup?):
            if current.start > day, setup.start != current.start {
                return (result.removing(today: day, calendar: calendar).plan
                    .creating(steps: setup.steps, end: setup.end, start: setup.start, base: newBase, today: day,
                              calendar: calendar), nil)
            }
            guard setup.steps != current.steps || setup.end != current.end else { return (result, nil) }
            return (result.editing(steps: setup.steps, end: setup.end, today: day, calendar: calendar), nil)
        case (_?, nil):
            let removed = result.removing(today: day, calendar: calendar)
            return (removed.plan, removed.newBase)
        case (nil, nil):
            return (result, nil)
        }
    }

    /// May a device that knows Pro isn't active hold the plan on `today` (§6)? Only a moving plan, not held already,
    /// and only when the Pro marker (`seenWithPro`, the last day a device knew Pro was active) is more than a day old:
    /// a device with Pro keeps it current, so two devices that disagree can't hold and resume back and forth.
    func canHold(on today: Date, seenWithPro: Date?, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: today)
        guard plan?.heldFrom == nil, isMoving(on: day, calendar: calendar) else { return false }
        guard let seenWithPro, let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return true }
        return calendar.startOfDay(for: seenWithPro) < yesterday
    }

    /// Held from `day` (the day the device found out), so days already gone by keep their steps.
    func holding(from day: Date, calendar: Calendar = .current) -> NutrientDosePlan {
        guard plan?.heldFrom == nil else { return self }
        var result = self
        result.plan?.heldFrom = calendar.startOfDay(for: day)
        return result
    }

    /// Pro is back on `today`: the plan goes on where it held. The held step (or, held before the start, the start)
    /// moves later by the days it was held, so those days keep the held goal and the later steps follow.
    func resuming(today: Date, calendar: Calendar = .current) -> NutrientDosePlan {
        guard var plan, let heldFrom = plan.heldFrom else { return self }
        let day = calendar.startOfDay(for: today)
        let held = max(0, calendar.dateComponents([.day], from: heldFrom, to: day).day ?? 0)
        if heldFrom < plan.start {
            plan.start = calendar.date(byAdding: .day, value: held, to: plan.start) ?? plan.start
        } else if let index = Self.stepIndex(of: plan, on: heldFrom, calendar: calendar) {
            plan.steps[index].days += held
        }
        plan.heldFrom = nil
        var result = self
        result.plan = plan
        return result
    }

    /// `history` with what the plan gave from `appliesFrom` up to (not including) `day` frozen as pieces. With no
    /// plan, a nil `base` piece is left as it is.
    private func frozen(through day: Date, base: NutrientGoal?, calendar: Calendar) -> NutrientDosePlan {
        var result = self
        guard let plan, plan.appliesFrom < day else { return result }
        result.history.removeAll { $0.from >= plan.appliesFrom }
        var date = plan.appliesFrom
        var last: NutrientGoal?? = .none
        while date < day {
            let goal = Self.goal(of: plan, on: date, calendar: calendar)
            if last != .some(goal) {
                // Before the plan's start its goal is the base goal; once frozen, the base goal it had.
                result.history.append(Piece(from: date, goal: goal ?? (base ?? history.last { $0.from <= date }?.goal)))
                last = .some(goal)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    // MARK: The steps

    fileprivate static func goal(of plan: Plan, on day: Date, calendar: Calendar) -> NutrientGoal? {
        let effective = plan.heldFrom.map { min(day, $0) } ?? day
        guard effective >= plan.start else { return nil }
        guard let index = stepIndex(of: plan, on: effective, calendar: calendar) else { return plan.steps.last?.goal }
        return plan.steps[index].goal
    }

    fileprivate static func stepIndex(of plan: Plan, on day: Date, calendar: Calendar) -> Int? {
        guard let offset = calendar.dateComponents([.day], from: plan.start, to: day).day, offset >= 0 else { return nil }
        var end = 0
        for (index, step) in plan.steps.enumerated() {
            end += step.days
            if offset < end { return index }
        }
        return nil
    }

    fileprivate static func lastDay(ofStep index: Int, in plan: Plan, calendar: Calendar) -> Date {
        let days = plan.steps.prefix(index + 1).reduce(0) { $0 + $1.days }
        return calendar.date(byAdding: .day, value: days - 1, to: plan.start) ?? plan.start
    }

    // MARK: Stored form

    /// "h=" the frozen pieces ("*" for the start of history, then "yyyyMMdd"; a goal "200", "120~160" or "base"),
    /// ";", then "p=" the plan: start, appliesFrom, keep or stop and an optional "held:yyyyMMdd", "|", the steps as
    /// goal "x" days. "h=*:200;p=20261110,20261110,keep|200x7,400x14".
    func encode(calendar: Calendar = .current) -> String {
        var parts: [String] = []
        if !history.isEmpty {
            parts.append("h=" + history.map { piece in
                let day = piece.from == .distantPast ? "*" : StoredDay.string(piece.from, calendar: calendar)
                return day + ":" + (piece.goal.map(Self.text) ?? "base")
            }.joined(separator: ","))
        }
        if let plan {
            var head = [StoredDay.string(plan.start, calendar: calendar), StoredDay.string(plan.appliesFrom, calendar: calendar),
                        plan.end.rawValue]
            if let heldFrom = plan.heldFrom { head.append("held:" + StoredDay.string(heldFrom, calendar: calendar)) }
            parts.append("p=" + head.joined(separator: ",") + "|"
                         + plan.steps.map { Self.text($0.goal) + "x\($0.days)" }.joined(separator: ","))
        }
        return parts.joined(separator: ";")
    }

    /// What it can't read is skipped: a damaged plan falls back to the base goal rather than failing.
    static func decode(_ raw: String, calendar: Calendar = .current) -> NutrientDosePlan {
        var result = NutrientDosePlan()
        for section in raw.split(separator: ";") {
            if section.hasPrefix("h=") {
                result.history = section.dropFirst(2).split(separator: ",").compactMap { text in
                    let halves = text.split(separator: ":", maxSplits: 1)
                    guard halves.count == 2 else { return nil }
                    let from = halves[0] == "*" ? Date.distantPast : StoredDay.date(halves[0], calendar: calendar)
                    guard let from else { return nil }
                    if halves[1] == "base" { return Piece(from: from, goal: nil) }
                    guard let goal = goal(halves[1]) else { return nil }
                    return Piece(from: from, goal: goal)
                }
                .sorted { $0.from < $1.from }
            } else if section.hasPrefix("p=") {
                result.plan = plan(section.dropFirst(2), calendar: calendar)
            }
        }
        return result
    }

    private static func plan(_ text: Substring, calendar: Calendar) -> Plan? {
        let halves = text.split(separator: "|", maxSplits: 1)
        guard halves.count == 2 else { return nil }
        let head = halves[0].split(separator: ",")
        guard head.count >= 3, let start = StoredDay.date(head[0], calendar: calendar),
              let appliesFrom = StoredDay.date(head[1], calendar: calendar),
              let end = End(rawValue: String(head[2])) else { return nil }
        let heldFrom = head.dropFirst(3).first { $0.hasPrefix("held:") }
            .flatMap { StoredDay.date($0.dropFirst(5), calendar: calendar) }
        let steps = halves[1].split(separator: ",").compactMap { text -> Step? in
            let pair = text.split(separator: "x")
            // Any length from 1: the sheet offers 1–90, but a resume lengthens the held step by the days it waited.
            guard pair.count == 2, let goal = goal(pair[0]), let days = Int(pair[1]), days > 0 else {
                return nil
            }
            return Step(goal: goal, days: days)
        }
        guard !steps.isEmpty else { return nil }
        return Plan(start: start, steps: steps, end: end, appliesFrom: appliesFrom, heldFrom: heldFrom)
    }

    private static func goal(_ text: Substring) -> NutrientGoal? {
        let values = text.split(separator: "~").compactMap { Double($0) }
        guard let target = values.first, target > 0 else { return nil }
        if values.count == 2 { return values[1] > target ? NutrientGoal(target: target, upperBound: values[1]) : nil }
        return values.count == 1 ? NutrientGoal(target: target) : nil
    }

    private static func text(_ goal: NutrientGoal) -> String {
        number(goal.target) + (goal.upperBound.map { "~" + number($0) } ?? "")
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }
}

extension NutrientDosePlan.Plan {
    /// Its goal on `day` (held: the step in effect when it held), or nil before its start.
    func goal(on day: Date, calendar: Calendar = .current) -> NutrientGoal? {
        NutrientDosePlan.goal(of: self, on: calendar.startOfDay(for: day), calendar: calendar)
    }

    /// Where `day` falls in its steps, held or not; nil before the start and after the last step.
    func position(on day: Date, calendar: Calendar = .current) -> NutrientDosePlan.Position? {
        guard let index = NutrientDosePlan.stepIndex(of: self, on: calendar.startOfDay(for: day), calendar: calendar)
        else { return nil }
        return NutrientDosePlan.Position(step: index + 1, count: steps.count,
                                         lastDay: NutrientDosePlan.lastDay(ofStep: index, in: self, calendar: calendar))
    }

    /// Each step's first and last day, in order.
    func stepDays(calendar: Calendar = .current) -> [ClosedRange<Date>] {
        steps.indices.map { index in
            let last = NutrientDosePlan.lastDay(ofStep: index, in: self, calendar: calendar)
            let first = calendar.date(byAdding: .day, value: 1 - steps[index].days, to: last) ?? last
            return first...last
        }
    }

    /// The last step's last day: a plan that stops ends its course there.
    func lastDay(calendar: Calendar = .current) -> Date {
        NutrientDosePlan.lastDay(ofStep: max(0, steps.count - 1), in: self, calendar: calendar)
    }

    /// The goal the base takes when the plan is removed on `day` (§3, §6), so nothing jumps: its kept last goal, or
    /// the held one. Nil while it's moving, before its start, or when there's no goal to keep, since the base goal
    /// is back then.
    func goalIfRemoved(on day: Date, calendar: Calendar = .current) -> NutrientGoal? {
        let start = calendar.startOfDay(for: day)
        let held = heldFrom.map { start >= $0 } ?? false
        let settled = end == .keep && start >= self.start
            && NutrientDosePlan.stepIndex(of: self, on: start, calendar: calendar) == nil
        return settled || held ? goal(on: start, calendar: calendar) : nil
    }
}

extension Nutrient {
    /// Read in the same calendar the caller matches days in.
    func dosePlan(calendar: Calendar = .current) -> NutrientDosePlan {
        NutrientDosePlan.decode(dosePlanRaw, calendar: calendar)
    }

    /// The goal set in the form: the target and, for a range, its maximum.
    var baseGoal: NutrientGoal {
        NutrientGoal(target: dailyTarget, upperBound: upperBound)
    }

    /// The goal on `day` (#135): its dose plan's goal when it has one for that day, else the base goal. Every goal
    /// reader goes through it (docs/pro/DOSE-PLANS.md §2): today's for Today, the widgets and the Watch, each past
    /// day's own for History, streaks, analytics, recaps and the report.
    func goal(on day: Date = .now, calendar: Calendar = .current) -> NutrientGoal {
        dosePlanRaw.isEmpty ? baseGoal : dosePlan(calendar: calendar).goal(on: day, calendar: calendar) ?? baseGoal
    }
}
