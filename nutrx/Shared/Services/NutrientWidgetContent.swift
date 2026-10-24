import Foundation

/// What the one-nutrient widget shows (nutrx Pro, #138, docs/pro/WIDGETS.md §3). Decided here so it's tested
/// (`NutrientWidgetContentTests`); also compiled into the widget extension.
enum NutrientWidgetContent: Equatable {
    /// Not Pro: what the widget is, with the PRO chip; a tap opens the paywall.
    case free
    /// Nothing picked, or the pick is gone from the store.
    case choose
    case nutrient(Shown)

    struct Shown: Equatable {
        let id: UUID
        let name: String
        let tint: NutrientTint
        let symbolName: String
        let status: Status
    }

    enum Status: Equatable {
        /// Due today: the ring, "2,000 / 4,000 IU", the status line and +.
        case due(GoalProgress)
        /// Off today under a schedule (#132): "Not today" and "Next: Sunday", no +.
        case notToday(next: String)
        case courseEnded
        case removed

        /// What shows instead of progress, a line each: "Not today" and "Next: Sunday", "Course ended",
        /// "Removed in nutrx"; none while due.
        var captions: [String] {
            switch self {
            case .due: []
            case .notToday(let next): [ScheduleText.notTodayTitle, next]
            case .courseEnded: ["Course ended"]
            case .removed: ["Removed in nutrx"]
            }
        }
    }

    /// `chosen`: the widget has a pick; `nutrient` is that pick read from the store (nil when it's gone).
    static func make(chosen: Bool, nutrient: Nutrient?, todayTotal: Double, isPro: Bool, now: Date = .now,
                     calendar: Calendar = .current, locale: Locale = .current) -> NutrientWidgetContent {
        guard isPro else { return .free }
        guard chosen, let nutrient else { return .choose }
        let status: Status
        if nutrient.isRemoved {
            status = .removed
        } else if nutrient.hasEnded(by: now, calendar: calendar) {
            status = .courseEnded
        } else if !nutrient.isDue(on: now, calendar: calendar) {
            let next = nutrient.nextDueDay(after: now, calendar: calendar)
            status = .notToday(next: ScheduleText(calendar: calendar, locale: locale).next(next, today: now))
        } else {
            status = .due(GoalProgress(nutrient: nutrient, current: max(0, todayTotal)))
        }
        return .nutrient(Shown(id: nutrient.id, name: nutrient.name, tint: nutrient.tint,
                               symbolName: nutrient.symbolName, status: status))
    }
}
