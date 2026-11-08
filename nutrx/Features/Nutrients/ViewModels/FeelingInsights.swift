import Foundation
import SwiftData

/// How you feel's clearest pattern across the nutrients (nutrx Pro, #133, docs/pro/HOW-YOU-FEEL.md §3): the line at
/// the end of the weekly and monthly recaps. A month covers about the 28 days the patterns look at, so both read the
/// 28 days up to the period's last day; the year gets none.
enum FeelingInsights {
    /// The largest finding of any running nutrient over the 28 days up to `lastDay`, with its nutrient.
    @MainActor
    static func clearest(context: ModelContext, through lastDay: Date,
                         calendar: Calendar = .current) -> (nutrient: Nutrient, finding: FeelingTrends.Finding)? {
        let questions = FeelingQuestions.active(in: context).map { FeelingTrends.Question($0, calendar: calendar) }
        guard !questions.isEmpty else { return nil }
        // The trends read the 28 days before "today": the day after the period ends.
        let today = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay))!
        let start = calendar.date(byAdding: .day, value: -(FeelingTrends.windowDays + 1), to: today)!
        let records = (try? context.fetch(FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= start && $0.date < today }))) ?? []
        var totals: [UUID: [Date: Double]] = [:]
        var logged: Set<Date> = []
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            logged.insert(day)
            if let id = record.nutrient?.id { totals[id, default: [:]][day, default: 0] += record.amount }
        }

        let nutrients = (try? context.fetch(FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isRemoved }))) ?? []
        var best: (nutrient: Nutrient, finding: FeelingTrends.Finding)?
        for nutrient in nutrients {
            let schedule = nutrient.schedule(calendar: calendar)
            // A weekly schedule's days don't count one by one (as in the analytics).
            guard schedule.weeklyTimes(on: lastDay, calendar: calendar) == nil else { continue }
            let firstTracked = calendar.startOfDay(for: nutrient.createdAt)
            let gaps = nutrient.courseGaps(calendar: calendar)
            let endDate = nutrient.endDate
            let state = FeelingTrends.state(
                totals: totals[nutrient.id] ?? [:], loggedDays: logged, questions: questions,
                goal: AnalyticsGoal(nutrient: nutrient, calendar: calendar),
                counts: { day in
                    day >= firstTracked && schedule.isCountedDay(day, calendar: calendar)
                        && NutrientCourse.includes(endDate, gaps: gaps, day: day, calendar: calendar)
                },
                today: today, calendar: calendar)
            guard case .findings(let findings) = state, let finding = findings.first else { continue }
            if finding.size > (best?.finding.size ?? 0) { best = (nutrient, finding) }
        }
        return best
    }

    /// The recap's line: the finding's sentence ("After days you reach your Magnesium goal, you rated your Sleep 4.6
    /// on average, vs 2.5 after other days."), or nil.
    @MainActor
    static func recapLine(context: ModelContext, through lastDay: Date, calendar: Calendar = .current) -> String? {
        guard let best = clearest(context: context, through: lastDay, calendar: calendar) else { return nil }
        let text = FeelingTrendText(nutrientName: best.nutrient.name, unit: best.nutrient.unit,
                                    goal: AnalyticsGoal(nutrient: best.nutrient, calendar: calendar))
        return text.sentence(best.finding)
    }
}
