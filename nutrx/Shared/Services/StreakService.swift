import Foundation
import SwiftData

struct StreakResult {
    let current: Int
    let best: Int
}

enum StreakService {
    /// Computes current and best streak from IntakeRecord history.
    /// A streak day is a completed past day where every active, non-excluded nutrient hit its target.
    @MainActor
    static func compute(context: ModelContext) -> StreakResult {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Fetch all non-deleted nutrients
        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
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

        // Helper: check if a day is a streak day
        func isDayStreakDay(_ day: Date) -> Bool {
            // Active nutrients on this day: non-deleted, created on or before this day
            let activeNutrients = nutrients.filter { nutrient in
                calendar.startOfDay(for: nutrient.createdAt) <= day
            }

            guard !activeNutrients.isEmpty else { return false }

            // Remove excluded nutrients
            let nonExcluded = activeNutrients.filter { nutrient in
                !exclusionSet.contains("\(day.timeIntervalSince1970)-\(nutrient.persistentModelID)")
            }

            // If all nutrients were excluded, treat as not a streak day
            guard !nonExcluded.isEmpty else { return false }

            let dayTotals = intakeByDayNutrient[day] ?? [:]

            // Every non-excluded nutrient must meet its target
            return nonExcluded.allSatisfy { nutrient in
                let total = dayTotals[nutrient.persistentModelID] ?? 0
                return total >= nutrient.dailyTarget
            }
        }

        // Walk backward from yesterday to compute current streak
        var currentStreak = 0
        var day = calendar.date(byAdding: .day, value: -1, to: today)!

        // Find the earliest record date to know when to stop
        let earliestDay = daysWithRecords.min() ?? today

        while day >= earliestDay {
            // If no records exist for this day, streak is broken
            guard daysWithRecords.contains(day) else { break }
            guard isDayStreakDay(day) else { break }
            currentStreak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        // Compute best streak by scanning all days with records
        let sortedDays = daysWithRecords.sorted()
        var bestStreak = 0
        var runningStreak = 0

        for i in sortedDays.indices {
            let d = sortedDays[i]
            if isDayStreakDay(d) {
                // Check if consecutive with previous day
                if i > 0 {
                    let prevDay = sortedDays[i - 1]
                    let expected = calendar.date(byAdding: .day, value: 1, to: prevDay)!
                    if d == expected && runningStreak > 0 {
                        runningStreak += 1
                    } else {
                        runningStreak = 1
                    }
                } else {
                    runningStreak = 1
                }
                bestStreak = max(bestStreak, runningStreak)
            } else {
                runningStreak = 0
            }
        }

        return StreakResult(current: currentStreak, best: bestStreak)
    }
}
