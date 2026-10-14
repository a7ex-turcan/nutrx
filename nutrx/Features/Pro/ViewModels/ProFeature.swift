import Foundation

/// What nutrx Pro adds (docs/pro/PLAN.md, D5 order), as the paywall and the Pro screen list them.
enum ProFeature: String, CaseIterable, Identifiable {
    case supply
    case scan
    case recap
    case health
    case report

    var id: Self { self }

    var title: String {
        switch self {
        case .supply: "Supply & refills"
        case .scan: "Scan a label"
        case .recap: "Weekly recap"
        case .health: "Trends with Apple Health"
        case .report: "A report for your doctor"
        }
    }

    /// The Pro screen's shorter name ("Report for your doctor").
    var shortTitle: String {
        self == .report ? "Report for your doctor" : title
    }

    var subtitle: String {
        switch self {
        case .supply: "Know when a bottle runs out"
        case .scan: "Add a nutrient from its bottle"
        case .recap: "Your week, summarised"
        case .health: "Intake against sleep and workouts"
        case .report: "A PDF of any period"
        }
    }

    var symbolName: String {
        switch self {
        case .supply: "waterbottle"
        case .scan: "text.viewfinder"
        case .recap: "calendar"
        case .health: "heart"
        case .report: "doc.text"
        }
    }

    var tint: NutrientTint {
        switch self {
        case .supply: .amber
        case .scan: .teal
        case .recap: .indigo
        case .health: .coral
        case .report: .blue
        }
    }

    /// Built and in the app. The paywall never advertises a feature that isn't (phase 4 ships supply first).
    var isShipped: Bool {
        false
    }

    /// What the paywall and the Pro screen list: the shipped features — or, in Debug builds before any has
    /// shipped, all of them, so the screens can be checked against the design.
    static var listed: [ProFeature] {
        let shipped = allCases.filter(\.isShipped)
        #if DEBUG
        return shipped.isEmpty ? allCases : shipped
        #else
        return shipped
        #endif
    }
}
