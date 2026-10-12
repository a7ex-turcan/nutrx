import Foundation
import SwiftData

enum AnalyticsPeriod: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }
    var days: Int { rawValue }
    var title: String { "\(rawValue) days" }
}

/// Fetches a nutrient's intake and builds the analytics screen's summaries. The maths lives in
/// `AnalyticsSummary` / `WeekdayPattern`; this only loads the day totals.
@Observable
final class NutrientAnalyticsViewModel {
    var selectedPeriod: AnalyticsPeriod = .week {
        didSet { if selectedPeriod != oldValue { refresh() } }
    }
    private(set) var goal: AnalyticsGoal
    private(set) var summary: AnalyticsSummary?
    private(set) var stats: [AnalyticsStat] = []
    private(set) var weekdayPattern: WeekdayPattern?

    private let nutrient: Nutrient
    private let modelContext: ModelContext

    init(nutrient: Nutrient, modelContext: ModelContext) {
        self.nutrient = nutrient
        self.modelContext = modelContext
        goal = AnalyticsGoal(nutrient: nutrient)
        refresh()
    }

    /// Re-reads the nutrient's goal and intake — call after an edit or when the screen reappears.
    func refresh(now: Date = .now) {
        let calendar = Calendar.current
        goal = AnalyticsGoal(nutrient: nutrient)
        let lookback = max(selectedPeriod.days, WeekdayPattern.windowDays + 1)
        let totals = dayTotals(daysBack: lookback, now: now, calendar: calendar)

        let summary = AnalyticsSummary(dayCount: selectedPeriod.days, totals: totals, goal: goal,
                                       createdAt: nutrient.createdAt, today: now, calendar: calendar)
        self.summary = summary
        stats = AnalyticsStat.triplet(for: summary, period: selectedPeriod, unit: nutrient.unit,
                                      goalType: nutrient.goalType, calendar: calendar)
        weekdayPattern = WeekdayPattern(totals: totals, goal: goal, createdAt: nutrient.createdAt,
                                        today: now, calendar: calendar)
    }

    /// Summed intake per day (keyed by start of day) from `daysBack - 1` days ago through today.
    private func dayTotals(daysBack: Int, now: Date, calendar: Calendar) -> [Date: Double] {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: startOfToday)!
        let end = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let nutrientID = nutrient.id
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID && $0.date >= start && $0.date < end
            }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.reduce(into: [:]) { totals, record in
            totals[calendar.startOfDay(for: record.date), default: 0] += record.amount
        }
    }
}
