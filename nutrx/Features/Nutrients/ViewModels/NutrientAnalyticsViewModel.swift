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
    /// Trends with Apple Health (nutrx Pro): nil until read, or when not connected.
    private(set) var healthState: HealthTrends.State?
    private(set) var isHealthConnected = HealthReader.isConnected

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
        let courseGaps = nutrient.courseGaps(calendar: calendar)

        let summary = AnalyticsSummary(dayCount: selectedPeriod.days, totals: totals, goal: goal,
                                       createdAt: nutrient.createdAt, endDate: nutrient.endDate,
                                       courseGaps: courseGaps, today: now,
                                       calendar: calendar)
        self.summary = summary
        stats = AnalyticsStat.triplet(for: summary, period: selectedPeriod, unit: nutrient.unit,
                                      goalType: nutrient.goalType, calendar: calendar)
        weekdayPattern = WeekdayPattern(totals: totals, goal: goal, createdAt: nutrient.createdAt,
                                        endDate: nutrient.endDate, courseGaps: courseGaps, today: now,
                                        calendar: calendar)
    }

    /// Reads Apple Health (live, never stored) and pairs it with the last four weeks of this nutrient.
    func refreshHealth(now: Date = .now) async {
        isHealthConnected = HealthReader.isConnected
        guard isHealthConnected else {
            healthState = nil
            return
        }
        let calendar = Calendar.current
        let days = HealthTrends.windowDays + 1
        let totals = dayTotals(daysBack: days, now: now, calendar: calendar)
        let logged = loggedDays(daysBack: days, now: now, calendar: calendar)
        let health = await HealthReader.recentDays(HealthTrends.windowDays, now: now, calendar: calendar)
        healthState = HealthTrends.state(totals: totals, loggedDays: logged, health: health, goal: goal,
                                         createdAt: nutrient.createdAt, today: now, calendar: calendar)
    }

    /// Days with anything logged (any nutrient), so a day nutrx wasn't used doesn't pair as 0.
    private func loggedDays(daysBack: Int, now: Date, calendar: Calendar) -> Set<Date> {
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: startOfToday)!
        let descriptor = FetchDescriptor<IntakeRecord>(predicate: #Predicate<IntakeRecord> { $0.date >= start })
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Set(records.map { calendar.startOfDay(for: $0.date) })
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
