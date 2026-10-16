import Foundation

/// What the report for your doctor says about a period (nutrx Pro, docs/pro/PLAN.md phase 8). Pure: built from a
/// `HistoryLog`, so a goal counts on a day exactly as in History and for streaks. Only days with something logged
/// in nutrx count toward hit rates and averages: a day nothing was logged is unknown, not a missed goal.
struct DoctorReport: Equatable {
    struct Day: Equatable {
        let date: Date
        /// The day's total, floored at 0; nil when the day doesn't count (not logged, or before the nutrient).
        let total: Double?
        let isMet: Bool
    }

    struct Section: Equatable {
        let id: UUID
        let name: String
        let unit: String
        let goalType: GoalType
        let target: Double
        let upperBound: Double?
        /// Every day of the period, oldest first.
        let days: [Day]
        let countedDays: Int
        let metDays: Int
        /// Days with an entry for this nutrient.
        let daysLogged: Int
        let average: Double?
        /// Apple Health trend sentences, when the report includes them.
        var trends: [String] = []

        var hitRate: Double? { countedDays > 0 ? Double(metDays) / Double(countedDays) : nil }
    }

    struct Note: Equatable {
        let date: Date
        let nutrientName: String
        let text: String
    }

    /// First and last day of the period (start of day), both included.
    let start: Date
    let end: Date
    let name: String?
    let sections: [Section]
    let notes: [Note]
    /// Days in the period with anything logged.
    let daysWithEntries: Int
    /// Goals met over goals counted, every nutrient, every logged day.
    let overallHitRate: Double?
    /// The longest run of logged days in the period with every included goal met.
    let longestStreak: Int
    /// Every day of the period, oldest first (empty when the period is).
    let days: [Date]

    var dayCount: Int { days.count }

    // MARK: - Building

    struct NoteEntry: Equatable {
        let date: Date
        let nutrientID: UUID
        let text: String
    }

    /// - Parameters:
    ///   - start, end: the period; `end` is clamped to yesterday (today isn't over).
    ///   - nutrientIDs: the nutrients to include, in display order; nil is every nutrient that counts in the period.
    ///   - names / units: by nutrient id.
    ///   - notes: entries' notes in the period (already trimmed and non-empty); only those for included nutrients stay.
    static func build(log: HistoryLog, names: [UUID: String], units: [UUID: String], start: Date, end: Date,
                      nutrientIDs: [UUID]? = nil, personName: String? = nil, notes: [NoteEntry] = []) -> DoctorReport {
        let calendar = log.calendar
        let yesterday = calendar.date(byAdding: .day, value: -1, to: log.today)!
        let first = calendar.startOfDay(for: start)
        let last = min(calendar.startOfDay(for: end), yesterday)
        var dates: [Date] = []
        var day = first
        while day <= last {
            dates.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let results = dates.map(log.day)
        let logged = results.filter(\.hasEntries)

        let included = nutrientIDs ?? log.nutrients.map(\.id).filter { id in results.contains { $0.goals.contains { $0.nutrientID == id } } }
        let byID = Dictionary(log.nutrients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let sections = included.compactMap { id -> Section? in
            guard let nutrient = byID[id] else { return nil }
            var days: [Day] = []
            var counted = 0, met = 0, daysLogged = 0, sum = 0.0
            for result in results {
                let goal = result.goals.first { $0.nutrientID == id }
                if log.loggedNutrients(on: result.date).contains(id) { daysLogged += 1 }
                guard let goal, result.hasEntries else {
                    days.append(Day(date: result.date, total: nil, isMet: false))
                    continue
                }
                counted += 1
                sum += goal.total
                if goal.isMet { met += 1 }
                days.append(Day(date: result.date, total: goal.total, isMet: goal.isMet))
            }
            return Section(id: id, name: names[id] ?? "", unit: units[id] ?? "", goalType: nutrient.goalType,
                           target: nutrient.target, upperBound: nutrient.upperBound, days: days,
                           countedDays: counted, metDays: met, daysLogged: daysLogged,
                           average: counted > 0 ? sum / Double(counted) : nil)
        }

        let counted = sections.reduce(0) { $0 + $1.countedDays }
        let met = sections.reduce(0) { $0 + $1.metDays }
        // A full day for this report: logged, and every included goal that counts that day met (a nutrient left out of
        // the report doesn't break its streak).
        let includedSet = Set(included)
        var longest = 0, run = 0
        for result in results {
            let goals = result.goals.filter { includedSet.contains($0.nutrientID) }
            if result.hasEntries, !goals.isEmpty, goals.allSatisfy(\.isMet) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        let reportNotes = notes
            .filter { includedSet.contains($0.nutrientID) && $0.date >= first && calendar.startOfDay(for: $0.date) <= last }
            .sorted { $0.date < $1.date }
            .map { Note(date: $0.date, nutrientName: names[$0.nutrientID] ?? "", text: $0.text) }

        let trimmedName = personName?.trimmingCharacters(in: .whitespaces)
        return DoctorReport(start: first, end: last, name: trimmedName?.isEmpty == false ? trimmedName : nil,
                            sections: sections, notes: reportNotes, daysWithEntries: logged.count,
                            overallHitRate: counted > 0 ? Double(met) / Double(counted) : nil,
                            longestStreak: longest, days: dates)
    }

    /// The last `days` completed days: "Last 30 days" ends yesterday.
    static func lastDays(_ days: Int, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: today)
        let end = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let start = calendar.date(byAdding: .day, value: -days, to: startOfToday)!
        return (start, end)
    }
}
