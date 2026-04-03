import Foundation
import SwiftData

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        }
    }
}

@Observable
final class NutrientAnalyticsViewModel {
    var selectedPeriod: AnalyticsPeriod = .week
    var dailyTotals: [(date: Date, total: Double)] = []
    var hitRate: (onTarget: Int, total: Int) = (0, 0)
    var periodAverage: Double = 0
    var dayOfWeekAverages: [(weekday: Int, label: String, average: Double)] = []

    private let nutrient: Nutrient
    private let modelContext: ModelContext

    init(nutrient: Nutrient, modelContext: ModelContext) {
        self.nutrient = nutrient
        self.modelContext = modelContext
        refresh()
        refreshDayOfWeek()
    }

    func refresh() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: today)!

        let nutrientID = nutrient.id
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID
                    && $0.date >= startDate
                    && $0.date < today
            }
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []

        // Group records by calendar day
        var dayMap: [Date: Double] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            dayMap[day, default: 0] += record.amount
        }

        // Build continuous array of days
        var result: [(date: Date, total: Double)] = []
        var onTarget = 0
        let target = nutrient.dailyTarget
        let goalType = nutrient.goalType
        let upper = nutrient.upperBound

        for offset in (0..<selectedPeriod.days).reversed() {
            let day = calendar.date(byAdding: .day, value: -(offset + 1), to: today)!
            let startOfDay = calendar.startOfDay(for: day)
            let total = max(0, dayMap[startOfDay] ?? 0)
            result.append((date: startOfDay, total: total))

            switch goalType {
            case .minimum:
                if total >= target { onTarget += 1 }
            case .maximum:
                if total <= target { onTarget += 1 }
            case .range:
                if let ub = upper, total >= target && total <= ub { onTarget += 1 }
            }
        }

        dailyTotals = result
        hitRate = (onTarget, selectedPeriod.days)

        let sum = result.reduce(0.0) { $0 + $1.total }
        periodAverage = result.isEmpty ? 0 : sum / Double(result.count)
    }

    private func refreshDayOfWeek() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -28, to: today)!

        let nutrientID = nutrient.id
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID
                    && $0.date >= startDate
                    && $0.date < today
            }
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []

        // Group by calendar day, then aggregate by weekday
        var dayMap: [Date: Double] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            dayMap[day, default: 0] += record.amount
        }

        // Only include days that have at least one record
        var weekdaySums: [Int: Double] = [:]
        var weekdayCounts: [Int: Int] = [:]
        for (day, total) in dayMap {
            let wd = calendar.component(.weekday, from: day)
            weekdaySums[wd, default: 0] += max(0, total)
            weekdayCounts[wd, default: 0] += 1
        }

        // Build Mon–Sun ordered array (weekday 2=Mon ... 7=Sat, 1=Sun)
        let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
        let symbols = calendar.shortWeekdaySymbols // ["Sun", "Mon", ...]
        dayOfWeekAverages = weekdayOrder.map { wd in
            let avg = weekdayCounts[wd, default: 0] > 0
                ? weekdaySums[wd, default: 0] / Double(weekdayCounts[wd]!)
                : 0
            return (weekday: wd, label: symbols[wd - 1], average: avg)
        }
    }
}
