import Foundation
import SwiftData

struct StreakResult {
    let current: Int
    let best: Int
}

enum StreakService {
    /// Computes current and best streak from IntakeRecord history.
    /// A streak day is a completed past day where every due, non-excluded nutrient hit its target. A rest day, with
    /// nothing due (schedules, #132), is stepped over: it neither breaks nor extends the streak.
    @MainActor
    static func compute(context: ModelContext) -> StreakResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Fetch all non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isRemoved }
        )
        guard let nutrients = try? context.fetch(nutrientDescriptor), !nutrients.isEmpty else {
            return StreakResult(current: 0, best: 0)
        }

        // Fetch all intake records (past only)
        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date < today }
        )
        guard let records = try? context.fetch(intakeDescriptor), !records.isEmpty else {
            return StreakResult(current: 0, best: 0)
        }

        // Fetch all exclusions
        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date < today }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []

        // Build intake totals by (day, nutrientID)
        var intakeByDayNutrient: [Date: [PersistentIdentifier: Double]] = [:]
        var daysWithRecords: Set<Date> = []

        for record in records {
            guard let nutrient = record.nutrient else { continue }
            let day = calendar.startOfDay(for: record.date)
            daysWithRecords.insert(day)
            intakeByDayNutrient[day, default: [:]][nutrient.persistentModelID, default: 0] += record.amount
        }

        // Build exclusion set by (day, nutrientID)
        var exclusionSet: Set<String> = []
        for exclusion in exclusions {
            guard let nutrient = exclusion.nutrient else { continue }
            let day = calendar.startOfDay(for: exclusion.date)
            exclusionSet.insert("\(day.timeIntervalSince1970)-\(nutrient.persistentModelID)")
        }

        // Decoded once, not per day.
        let courseGaps = Dictionary(nutrients.map { ($0.persistentModelID, $0.courseGaps(calendar: calendar)) },
                                    uniquingKeysWith: { first, _ in first })
        let schedules = Dictionary(nutrients.map { ($0.persistentModelID, $0.schedule(calendar: calendar)) },
                                   uniquingKeysWith: { first, _ in first })

        /// A rest day had nothing due (every nutrient off its schedule, past its course or not created yet): it
        /// neither breaks nor extends a streak (#132).
        enum DayStatus { case rest, streak, broken }

        func status(_ day: Date) -> DayStatus {
            // Due on this day: non-deleted, created on or before it, course not over (#99), a dose day (#132)
            let due = nutrients.filter { nutrient in
                calendar.startOfDay(for: nutrient.createdAt) <= day
                    && NutrientCourse.includes(nutrient.endDate, gaps: courseGaps[nutrient.persistentModelID] ?? [],
                                               day: day, calendar: calendar)
                    // TODO(#132 phase 4): add a weekly schedule's met days (`weeklyCountedDays`); until then a
                    // weekly-only setup is all rest days. It can't be set before phase 4.
                    && schedules[nutrient.persistentModelID]?.isCountedDay(day, calendar: calendar) ?? true
            }
            guard !due.isEmpty else { return .rest }

            // Something was due and nothing was logged: broken
            guard daysWithRecords.contains(day) else { return .broken }

            // Remove excluded nutrients; if all were excluded, it isn't a streak day
            let nonExcluded = due.filter { nutrient in
                !exclusionSet.contains("\(day.timeIntervalSince1970)-\(nutrient.persistentModelID)")
            }
            guard !nonExcluded.isEmpty else { return .broken }

            let dayTotals = intakeByDayNutrient[day] ?? [:]

            // Every non-excluded nutrient must meet its goal
            let allMet = nonExcluded.allSatisfy { nutrient in
                let total = dayTotals[nutrient.persistentModelID] ?? 0
                return GoalProgress(nutrient: nutrient, current: total).countsAsMet
            }
            return allMet ? .streak : .broken
        }

        // Walk backward from yesterday to compute current streak, stepping over rest days
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let earliestDay = daysWithRecords.min() ?? today
        var currentStreak = 0
        var day = yesterday
        walk: while day >= earliestDay {
            switch status(day) {
            case .rest: break
            case .streak: currentStreak += 1
            case .broken: break walk
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        // Best streak: every day from the first record to yesterday, rest days stepped over
        var bestStreak = 0
        var runningStreak = 0
        day = earliestDay
        while day <= yesterday {
            switch status(day) {
            case .rest: break
            case .streak:
                runningStreak += 1
                bestStreak = max(bestStreak, runningStreak)
            case .broken: runningStreak = 0
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        return StreakResult(current: currentStreak, best: bestStreak)
    }
}
