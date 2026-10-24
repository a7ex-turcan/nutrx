import Foundation

/// What the supply & courses widget lists (nutrx Pro, #138, docs/pro/WIDGETS.md §4): supply that's low or out and
/// courses within a week of their last day, soonest first. Pure, tested in `SupplyWidgetSummaryTests`; also compiled
/// into the widget extension.
struct SupplyWidgetSummary: Equatable {
    struct Item: Equatable, Identifiable {
        enum Kind: Equatable {
            case supply
            case course
        }

        let nutrientID: UUID
        let name: String
        let tint: NutrientTint
        let symbolName: String
        let kind: Kind
        /// Supply only: nothing left.
        let isOut: Bool
        /// Whole days left; 0 when out, or on a course's last day.
        let daysLeft: Int

        /// A nutrient can be listed twice (a low bottle and an ending course).
        var id: String { "\(nutrientID.uuidString)-\(kind)" }

        /// After the name on the Home Screen: "6 days left", "out", "last day", "ends tomorrow".
        var detail: String {
            switch kind {
            case .supply:
                if isOut { return "out" }
                switch daysLeft {
                case ...0: return "runs out today"
                case 1: return "1 day left"
                default: return "\(daysLeft) days left"
                }
            case .course:
                switch daysLeft {
                case ...0: return "last day"
                case 1: return "ends tomorrow"
                default: return "ends in \(daysLeft) days"
                }
            }
        }

        /// After the name on the Lock Screen: "6 days", "out", "last day", "tomorrow".
        var shortDetail: String {
            switch (kind, daysLeft) {
            case (.supply, _) where isOut: "out"
            case (.supply, ...0): "today"
            case (.course, ...0): "last day"
            case (_, 1): kind == .course ? "tomorrow" : "1 day"
            default: "\(daysLeft) days"
            }
        }
    }

    /// Soonest first.
    let items: [Item]
    /// Running nutrients with supply set, and with a course: the "on track" line.
    let bottles: Int
    let courses: Int

    /// Courses show from this many days before their last day.
    static let courseWindowDays = 7
    static let onTrackTitle = "Supply and courses on track"
    static let freeTitle = "Know when a bottle runs out"

    /// "4 bottles, 1 course", or how to start when there's neither.
    var trackedLine: String {
        var parts: [String] = []
        if bottles > 0 { parts.append(bottles == 1 ? "1 bottle" : "\(bottles) bottles") }
        if courses > 0 { parts.append(courses == 1 ? "1 course" : "\(courses) courses") }
        return parts.isEmpty ? "Set up supply or a course on a nutrient." : parts.joined(separator: ", ")
    }

    /// `nutrients` in Today's order, which breaks ties. Removed and ended ones are left out.
    static func make(_ nutrients: [Nutrient], now: Date = .now,
                     calendar: Calendar = .current) -> SupplyWidgetSummary {
        var items: [Item] = []
        var bottles = 0, courses = 0
        let today = calendar.startOfDay(for: now)
        for nutrient in nutrients where nutrient.isRunning(on: now, calendar: calendar) {
            func item(_ kind: Item.Kind, isOut: Bool = false, daysLeft: Int) -> Item {
                Item(nutrientID: nutrient.id, name: nutrient.name, tint: nutrient.tint,
                     symbolName: nutrient.symbolName, kind: kind, isOut: isOut, daysLeft: max(0, daysLeft))
            }
            if let status = nutrient.supplyStatus(now: now, calendar: calendar) {
                bottles += 1
                switch status.level {
                case .out: items.append(item(.supply, isOut: true, daysLeft: 0))
                case .low: items.append(item(.supply, daysLeft: status.daysLeft ?? 0))
                case .plenty, .noHistory: break
                }
            }
            if let endDate = nutrient.endDate {
                courses += 1
                let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: endDate)).day ?? 0
                if days <= courseWindowDays { items.append(item(.course, daysLeft: days)) }
            }
        }
        return SupplyWidgetSummary(items: ordered(items), bottles: bottles, courses: courses)
    }

    /// Out first, then the fewest days left (a course's last day is 0), a bottle before a course on the same day,
    /// then the order given.
    static func ordered(_ items: [Item]) -> [Item] {
        items.enumerated().sorted { lhs, rhs in
            let l = lhs.element, r = rhs.element
            if l.isOut != r.isOut { return l.isOut }
            if l.daysLeft != r.daysLeft { return l.daysLeft < r.daysLeft }
            if l.kind != r.kind { return l.kind == .supply }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }
}
