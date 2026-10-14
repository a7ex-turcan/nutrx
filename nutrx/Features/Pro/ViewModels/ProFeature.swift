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

    /// In a run of names on Settings' card: "supply, label scan, recaps…" (`ProText.tagline`).
    var shortName: String {
        switch self {
        case .supply: "supply"
        case .scan: "label scan"
        case .recap: "recaps"
        case .health: "Health trends"
        case .report: "doctor reports"
        }
    }

    /// In the welcome sentence: "supply, label scanning, weekly recaps… are on" (`ProText.welcome`).
    var welcomeName: String {
        switch self {
        case .supply: "supply"
        case .scan: "label scanning"
        case .recap: "weekly recaps"
        case .health: "Apple Health trends"
        case .report: "doctor reports"
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
        self == .supply
    }

    /// What the paywall and the Pro screen list: the shipped features — or, in Debug builds before any has
    /// shipped, all of them, so the screens can be checked against the design.
    static var listed: [ProFeature] {
        #if DEBUG
        listed(shipped: allCases.filter(\.isShipped), debug: true)
        #else
        listed(shipped: allCases.filter(\.isShipped), debug: false)
        #endif
    }

    /// The rule behind `listed`, testable for both build configurations.
    static func listed(shipped: [ProFeature], debug: Bool) -> [ProFeature] {
        debug && shipped.isEmpty ? allCases : shipped
    }
}
