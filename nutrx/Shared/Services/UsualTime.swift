import Foundation

/// When something is usually logged by (nutrx Pro, #137, docs/pro/REMINDERS.md §2): the time by which it was logged
/// on about 3 days in 4 over the last 28 completed days, so a reminder then only nudges when you're running late.
/// Pure. Learned from the store's own record times, recomputed, never stored or synced.
enum UsualTime {
    /// Whether the reminders sheets offer it (§6): once `ProFeature.reminders` ships, and in Debug builds before.
    static var isAvailable: Bool {
        #if DEBUG
        true
        #else
        ProFeature.reminders.isShipped
        #endif
    }

    /// The starting time when switching with no set reminder to start from: 9:00.
    static let defaultStartMinutes = 9 * 60

    /// Completed days looked back over; today never counts.
    static let windowDays = 28
    /// Samples needed before a time is learned.
    static let minimumSamples = 7
    /// Weekdays and weekends each need this many samples for times of their own…
    static let splitMinimumSamples = 4
    /// …and to be at least this far apart (minutes).
    static let splitMinimumGap = 60
    /// Nothing later than 23:30; a habit around midnight keeps the set time.
    static let latestMinutes = 23 * 60 + 30
    /// Learned times are rounded up to this many minutes.
    static let step = 5

    /// One day's first log: minutes after midnight.
    struct Sample: Equatable {
        let day: Date
        let minutes: Int
    }

    enum Result: Equatable {
        /// Fewer than `minimumSamples`: "Learning, 3 of 7 days", and the set time is used.
        case learning(samples: Int)
        /// Minutes after midnight; the same for both when weekdays and weekends don't differ.
        case learned(weekdays: Int, weekends: Int)
        /// The learned time would be after `latestMinutes`: the set time is used.
        case tooLate

        var isLearned: Bool { if case .learned = self { true } else { false } }

        /// The time for `day`, when learned.
        func minutes(on day: Date, calendar: Calendar = .current) -> Int? {
            guard case let .learned(weekdays, weekends) = self else { return nil }
            return calendar.isDateInWeekend(day) ? weekends : weekdays
        }
    }

    /// When a usual-time reminder is planned (§5): the learned time with Pro, or while the entitlement isn't known
    /// yet (`isPro` nil: a cold background launch, so a background sync never moves it back), else the starting time.
    static func planned(start: Int, result: Result, isPro: Bool?) -> (weekdays: Int, weekends: Int) {
        if isPro != false, case let .learned(weekdays, weekends) = result { return (weekdays, weekends) }
        return (start, start)
    }

    /// The first log on each day in the window ending yesterday that was due (`isDue`) and logged. `logs` are the
    /// times of entries that added something (a decrement isn't a log).
    static func samples(logs: [Date], today: Date, isDue: (Date) -> Bool, calendar: Calendar = .current) -> [Sample] {
        let today = calendar.startOfDay(for: today)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: today) else { return [] }
        var first: [Date: Date] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log)
            guard day >= start, day < today else { continue }
            if let earlier = first[day], earlier <= log { continue }
            first[day] = log
        }
        return first.keys.sorted().compactMap { day in
            guard isDue(day), let log = first[day] else { return nil }
            let parts = calendar.dateComponents([.hour, .minute], from: log)
            return Sample(day: day, minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        }
    }

    /// A stack's samples (§2): on a day every one of its due nutrients was logged, the latest of their first logs,
    /// the moment the stack was done however it was logged. `nutrients` holds each nutrient's own samples.
    static func stackSamples(_ nutrients: [(samples: [Sample], isDue: (Date) -> Bool)]) -> [Sample] {
        let days = Set(nutrients.flatMap { $0.samples.map(\.day) })
        return days.sorted().compactMap { day in
            var latest: Int?
            var any = false
            for nutrient in nutrients where nutrient.isDue(day) {
                guard let sample = nutrient.samples.first(where: { $0.day == day }) else { return nil }
                latest = max(latest ?? sample.minutes, sample.minutes)
                any = true
            }
            return any ? latest.map { Sample(day: day, minutes: $0) } : nil
        }
    }

    static func result(_ samples: [Sample], calendar: Calendar = .current) -> Result {
        guard samples.count >= minimumSamples else { return .learning(samples: samples.count) }
        let weekend = samples.filter { calendar.isDateInWeekend($0.day) }.map(\.minutes)
        let weekday = samples.filter { !calendar.isDateInWeekend($0.day) }.map(\.minutes)
        var times = (weekdays: percentile(samples.map(\.minutes)), weekends: percentile(samples.map(\.minutes)))
        if weekday.count >= splitMinimumSamples, weekend.count >= splitMinimumSamples {
            let split = (weekdays: percentile(weekday), weekends: percentile(weekend))
            if abs(split.weekdays - split.weekends) >= splitMinimumGap { times = split }
        }
        guard times.weekdays <= latestMinutes, times.weekends <= latestMinutes else { return .tooLate }
        return .learned(weekdays: times.weekdays, weekends: times.weekends)
    }

    /// The 75th percentile (nearest rank) of `minutes`, rounded up to the next `step`.
    static func percentile(_ minutes: [Int]) -> Int {
        let sorted = minutes.sorted()
        guard !sorted.isEmpty else { return 0 }
        let rank = Int((Double(sorted.count) * 0.75).rounded(.up))
        let value = sorted[max(0, rank - 1)]
        return (value + step - 1) / step * step
    }
}

extension Nutrient {
    /// Its usual time from its own records of the last `UsualTime.windowDays` completed days: the first log on each
    /// day it was running and due (§2).
    func usualTime(now: Date = .now, calendar: Calendar = .current) -> UsualTime.Result {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -UsualTime.windowDays, to: today) else {
            return .learning(samples: 0)
        }
        let logs = records(from: start, to: today).filter { $0.amount > 0 }.map(\.date)
        let schedule = schedule(calendar: calendar)
        let samples = UsualTime.samples(logs: logs, today: now, isDue: { day in
            self.isRunning(on: day, calendar: calendar) && schedule.isDoseDay(day, calendar: calendar)
        }, calendar: calendar)
        return UsualTime.result(samples, calendar: calendar)
    }
}
