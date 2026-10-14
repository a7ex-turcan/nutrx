import Foundation

/// The words around supply (docs/pro/design/3-supply): Today's hint, the analytics card and the Supply sheet.
enum SupplyText {
    /// Today's hint after the goal status, or nil when nothing shows (plenty, no history).
    static func todayHint(_ status: SupplySchedule.Status) -> String? {
        switch status.level {
        case .out: "Out of supply"
        case .low: daysLeftPhrase(status.daysLeft ?? 0)
        case .plenty, .noHistory: nil
        }
    }

    /// The short form for a tight card: "6 days left", "1 day left", "Runs out today".
    static func shortHint(_ status: SupplySchedule.Status) -> String? {
        guard status.level == .low else { return todayHint(status) }
        switch status.daysLeft ?? 0 {
        case ...0: return "Runs out today"
        case 1: return "1 day left"
        case let days: return "\(days.formatted()) days left"
        }
    }

    /// The tightest form, next to the bottle symbol: "6 days", "1 day", "Today".
    static func compactHint(_ status: SupplySchedule.Status) -> String? {
        guard status.level == .low else { return nil }
        switch status.daysLeft ?? 0 {
        case ...0: return "Today"
        case 1: return "1 day"
        case let days: return "\(days.formatted()) days"
        }
    }

    /// "About 6 days left", "About 1 day left", "Runs out today".
    static func daysLeftPhrase(_ days: Int) -> String {
        switch days {
        case ...0: "Runs out today"
        case 1: "About 1 day left"
        default: "About \(days.formatted()) days left"
        }
    }

    /// The analytics card's count, markdown with the count in bold: "**12** of 120 left".
    static func servingsLine(_ status: SupplySchedule.Status, locale: Locale = .current) -> String {
        "**\(status.servingsLeft.formatted(.number.locale(locale)))** of \(status.setup.servings.formattedAmount(locale: locale)) left"
    }

    /// Markdown: "At your usual **2,000 IU** a day. Reminder at 7 days left. Last refilled 16 August." (the year
    /// only when it isn't this year) — or, before there's enough history, "Days-left estimate after a few days of
    /// logging."
    static func explanation(_ status: SupplySchedule.Status, unit: String, now: Date = .now,
                            calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let dailyUse = status.dailyUse else { return "Days-left estimate after a few days of logging." }
        let sameYear = calendar.isDate(status.setup.refilledAt, equalTo: now, toGranularity: .year)
        let style = sameYear ? Date.FormatStyle().day().month(.wide) : Date.FormatStyle().day().month(.wide).year()
        let refilled = status.setup.refilledAt.formatted(style.locale(locale))
        let days = status.setup.reminderDays == 1 ? "1 day" : "\(status.setup.reminderDays) days"
        return "At your usual **\(amount(usual(dailyUse), unit: unit, locale: locale))** a day. Reminder at \(days) left. "
            + "Last refilled \(refilled)."
    }

    /// The Supply sheet's sentence, markdown: "That's **120,000 IU** — about 60 days at your usual 2,000 IU a day."
    /// Without history it uses the goal ("at your goal of 4,000 IU a day"); with neither, just the total.
    static func bottleSentence(servings: Double, servingAmount: Double, unit: String, dailyUse: Double?,
                               dailyGoal: Double, locale: Locale = .current) -> String {
        let total = "That's **\(amount(servings * servingAmount, unit: unit, locale: locale))**"
        if let dailyUse, let days = SupplySchedule.daysInBottle(servings: servings, servingAmount: servingAmount,
                                                                 dailyAmount: dailyUse) {
            return "\(total) — about \(daysPhrase(days)) at your usual \(amount(usual(dailyUse), unit: unit, locale: locale)) a day."
        }
        if let days = SupplySchedule.daysInBottle(servings: servings, servingAmount: servingAmount, dailyAmount: dailyGoal) {
            return "\(total) — about \(daysPhrase(days)) at your goal of \(amount(dailyGoal, unit: unit, locale: locale)) a day."
        }
        return "\(total)."
    }

    /// The form row's value: "120 servings", or "Off".
    static func formSummary(servings: Double?, locale: Locale = .current) -> String {
        guard let servings, servings > 0 else { return "Off" }
        return servings == 1 ? "1 serving" : "\(servings.formattedAmount(locale: locale)) servings"
    }

    /// An average shown as a round number: 3,928.57 → 3,930; 412.5 → 413; 1.86 → 1.9.
    static func usual(_ value: Double) -> Double {
        switch value {
        case 1000...: (value / 10).rounded() * 10
        case 10...: value.rounded()
        default: (value * 10).rounded() / 10
        }
    }

    private static func daysPhrase(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days.formatted()) days"
    }

    private static func amount(_ value: Double, unit: String, locale: Locale) -> String {
        unit.isEmpty ? value.formattedAmount(locale: locale) : "\(value.formattedAmount(locale: locale)) \(unit)"
    }
}
