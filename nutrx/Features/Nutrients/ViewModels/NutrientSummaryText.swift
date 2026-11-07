import Foundation

/// One-line summaries of a nutrient's setup for the analytics screen (DESIGN.md §5.3).
enum NutrientSummaryText {
    /// "At least 4,000 IU a day · Morning stack" — the group only when there is one besides General. A dose plan's
    /// step goes after the goal: "At least 400 mg a day · Step 2 of 3, until 20 Nov · Morning stack" (#135).
    static func goalLine(goalType: GoalType, goalAmount: String, planPart: String? = nil, groupName: String?) -> String {
        let goal = "\(GoalTypePicker.label(for: goalType)) \(goalAmount) a day"
        return ([goal] + [planPart, groupName].compactMap { $0 }).joined(separator: " · ")
    }

    static func goalLine(for nutrient: Nutrient, now: Date = .now) -> String {
        let group = nutrient.group.flatMap { $0.isSystem ? nil : $0.name }
        let planPart = nutrient.dosePlanRaw.isEmpty ? nil
            : DosePlanText(goalType: nutrient.goalType, unit: nutrient.unit).headerPart(nutrient.dosePlan(), today: now)
        return goalLine(goalType: nutrient.goalType,
                        goalAmount: GoalProgress(nutrient: nutrient, current: 0, on: now).goalAmountText,
                        planPart: planPart, groupName: group)
    }

    /// Reminder times in time-of-day order: "None", "13:00", "8:00, 20:00", or "3 a day" once they stop fitting.
    static func reminderSummary(times: [Date], calendar: Calendar = .current, locale: Locale = .current) -> String {
        let sorted = times.sorted { lhs, rhs in
            let l = calendar.dateComponents([.hour, .minute], from: lhs)
            let r = calendar.dateComponents([.hour, .minute], from: rhs)
            return (l.hour ?? 0, l.minute ?? 0) < (r.hour ?? 0, r.minute ?? 0)
        }
        switch sorted.count {
        case 0:
            return "None"
        case 1...2:
            var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar)
            style.timeZone = calendar.timeZone
            return sorted.map { $0.formatted(style) }.joined(separator: ", ")
        default:
            return "\(sorted.count) a day"
        }
    }

    /// At its usual time (nutrx Pro, #137): "Usually by 8:30", "Learning (9:00)" (`UsualTimeText.summary`).
    static func reminderSummary(for nutrient: Nutrient, isPro: Bool) -> String {
        guard nutrient.remindsAtUsualTime else { return reminderSummary(times: (nutrient.reminders ?? []).map(\.timeOfDay)) }
        return UsualTimeText.summary(NotificationService.usualTime(of: nutrient),
                                     start: UsualTimeText.time(nutrient.usualReminderMinutes), isPro: isPro)
    }
}
