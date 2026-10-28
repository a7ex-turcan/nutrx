import Foundation

/// The paywall's rows: related Pro features share one, so the list stays short enough for the plans to show (eight
/// rows of their own pushed them below the fold). The Pro screen and "Enjoy nutrx Pro" keep a row per `ProFeature`.
/// Every shipped feature belongs to exactly one group (`ProFeatureGroupTests`), so a new one gets a place here once it
/// ships.
enum ProFeatureGroup: String, CaseIterable, Identifiable {
    case supply
    case plans
    case insights
    case widgets

    var id: Self { self }

    var features: [ProFeature] {
        switch self {
        case .supply: [.supply, .scan]
        case .plans: [.courses, .schedules, .reminders]
        case .insights: [.recap, .health, .report]
        case .widgets: [.widgets]
        }
    }

    var title: String {
        switch self {
        case .supply: "Supply & label scan"
        case .plans: "Courses, schedules & reminders"
        case .insights: "Recaps, trends & reports"
        case .widgets: ProFeature.widgets.title
        }
    }

    var subtitle: String {
        switch self {
        case .supply: "Know when a bottle runs out and what it costs, and add one from its label"
        case .plans: "Take something for a set time or on set days, and get a nudge when you're running late"
        case .insights: "Your week, month and year summarised, Apple Health trends, and a PDF for your doctor"
        case .widgets: ProFeature.widgets.subtitle
        }
    }

    var symbolName: String {
        switch self {
        case .supply: ProFeature.supply.symbolName
        case .plans: ProFeature.courses.symbolName
        case .insights: "chart.line.uptrend.xyaxis"
        case .widgets: ProFeature.widgets.symbolName
        }
    }

    var tint: NutrientTint {
        switch self {
        case .supply: ProFeature.supply.tint
        case .plans: ProFeature.courses.tint
        case .insights: ProFeature.recap.tint
        case .widgets: ProFeature.widgets.tint
        }
    }

    /// The groups to show for `features` (the listed ones), in order: any with at least one of them. A group's title
    /// and subtitle name all its features, so it only holds shipped ones (`ProFeatureGroupTests`): a feature that
    /// isn't shipped yet waits outside the groups, or the paywall would advertise it.
    static func groups(listing features: [ProFeature]) -> [ProFeatureGroup] {
        allCases.filter { !Set($0.features).isDisjoint(with: features) }
    }

    /// What the paywall lists.
    static var listed: [ProFeatureGroup] {
        groups(listing: ProFeature.listed)
    }
}
