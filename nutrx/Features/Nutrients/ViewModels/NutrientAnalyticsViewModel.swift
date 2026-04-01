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

    private let nutrient: Nutrient
    private let modelContext: ModelContext

    init(nutrient: Nutrient, modelContext: ModelContext) {
        self.nutrient = nutrient
        self.modelContext = modelContext
        refresh()
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
        for offset in (0..<selectedPeriod.days).reversed() {
            let day = calendar.date(byAdding: .day, value: -(offset + 1), to: today)!
            let startOfDay = calendar.startOfDay(for: day)
            let total = max(0, dayMap[startOfDay] ?? 0)
            result.append((date: startOfDay, total: total))
            if total >= nutrient.dailyTarget {
                onTarget += 1
            }
        }

        dailyTotals = result
        hitRate = (onTarget, selectedPeriod.days)

        let sum = result.reduce(0.0) { $0 + $1.total }
        periodAverage = result.isEmpty ? 0 : sum / Double(result.count)
    }
}
