import Foundation

/// One column of the analytics `StatTriplet`, already formatted for display.
struct AnalyticsStat: Identifiable, Equatable {
    let label: String
    let value: String
    /// Smaller text after the value, e.g. "%".
    var suffix: String? = nil
    let caption: String

    var id: String { label }
}

extension AnalyticsStat {
    static let placeholder = "—"

    /// Hit rate / Daily avg / Best day for a period (DESIGN.md §4.8).
    /// For "at most" and range goals the highest day isn't the best one, so it's labelled "Peak day".
    static func triplet(for summary: AnalyticsSummary, period: AnalyticsPeriod, unit: String, goalType: GoalType,
                        calendar: Calendar = .current, locale: Locale = .current) -> [AnalyticsStat] {
        let hitRate: AnalyticsStat = if let rate = summary.hitRate {
            AnalyticsStat(label: "Hit rate", value: (rate * 100).rounded().formattedAmount(locale: locale, maxFractionDigits: 0),
                          suffix: "%",
                          caption: "\(summary.metDays) of \(summary.countedDays) \(summary.countedDays == 1 ? "day" : "days")")
        } else {
            AnalyticsStat(label: "Hit rate", value: placeholder, caption: "No full days yet")
        }

        let average = AnalyticsStat(label: "Daily avg",
                                    value: summary.average.map { averageText($0, locale: locale) } ?? placeholder,
                                    caption: unit)

        let bestLabel = goalType == .minimum ? "Best day" : "Peak day"
        let best: AnalyticsStat = if let day = summary.bestDay {
            AnalyticsStat(label: bestLabel, value: day.total.formattedAmount(locale: locale),
                          caption: dayText(day.date, period: period, calendar: calendar, locale: locale))
        } else {
            AnalyticsStat(label: bestLabel, value: placeholder, caption: "Nothing logged")
        }

        return [hitRate, average, best]
    }

    /// Fewer decimals the bigger the average gets: "3,830", "12.4", "1.75".
    static func averageText(_ value: Double, locale: Locale = .current) -> String {
        let digits = switch abs(value) {
        case 100...: 0
        case 10..<100: 1
        default: 2
        }
        return value.formattedAmount(locale: locale, maxFractionDigits: digits)
    }

    /// The weekday within a week ("Friday"); a short date over longer periods ("3 Oct").
    private static func dayText(_ date: Date, period: AnalyticsPeriod, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return period == .week
            ? date.formatted(style.weekday(.wide))
            : date.formatted(style.day().month(.abbreviated))
    }
}
