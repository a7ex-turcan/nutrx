import Foundation

/// What nutrx Pro adds (docs/pro/PLAN.md, D5 order, then courses from 2.2, schedules from 2.4, widgets and controls
/// from 2.5, and reminders at your usual time being built for 2.6), as the paywall and the Pro screen list them.
enum ProFeature: String, CaseIterable, Identifiable {
    case supply
    case scan
    case recap
    case health
    case report
    case courses
    case schedules
    case widgets
    case reminders

    var id: Self { self }

    var title: String {
        switch self {
        case .supply: "Supply & refills"
        case .scan: "Scan a label"
        case .recap: "Recaps"
        case .health: "Trends with Apple Health"
        case .report: "A report for your doctor"
        case .courses: "Courses"
        case .schedules: "Schedules"
        case .widgets: "Widgets and controls"
        case .reminders: "Reminders at your usual time"
        }
    }

    /// The Pro screen's shorter name ("Report for your doctor").
    var shortTitle: String {
        self == .report ? "Report for your doctor" : title
    }

    var subtitle: String {
        switch self {
        case .supply: "Know when a bottle runs out, and what it costs"
        case .scan: "Add a nutrient from its bottle"
        case .recap: "Your week, month and year, summarised"
        case .health: "Intake against sleep and workouts"
        case .report: "A PDF of any period"
        case .courses: "Take something for a set time"
        case .schedules: "Take something on set days"
        case .widgets: "Log from Control Center and the Home Screen"
        case .reminders: "A nudge only when you're running late"
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
        case .courses: "courses"
        case .schedules: "schedules"
        case .widgets: "widgets"
        case .reminders: "smarter reminders"
        }
    }

    /// In the welcome sentence: "supply, label scanning, recaps… are on" (`ProText.welcome`).
    var welcomeName: String {
        switch self {
        case .supply: "supply"
        case .scan: "label scanning"
        case .recap: "recaps"
        case .health: "Apple Health trends"
        case .report: "doctor reports"
        case .courses: "courses"
        case .schedules: "schedules"
        case .widgets: "widgets"  // "…, schedules and widgets are on": "and controls" doubled the "and"
        case .reminders: "reminders at your usual time"
        }
    }

    /// What Apple Intelligence improves, in the paywall's note for devices without it; nil for features it doesn't.
    var appleIntelligenceName: String? {
        switch self {
        case .scan: "label scanning"
        case .recap: "recaps"
        case .supply, .health, .report, .courses, .schedules, .widgets, .reminders: nil
        }
    }

    var symbolName: String {
        switch self {
        case .supply: "waterbottle"
        case .scan: "text.viewfinder"
        case .recap: "calendar"
        case .health: "heart"
        case .report: "doc.text"
        case .courses: "hourglass"
        case .schedules: "calendar.badge.clock"
        case .widgets: "square.grid.2x2"
        case .reminders: "bell.badge"
        }
    }

    var tint: NutrientTint {
        switch self {
        case .supply: .amber
        case .scan: .teal
        case .recap: .indigo
        case .health: .coral
        case .report: .blue
        case .courses: .green
        case .schedules: .pink
        case .widgets: .brown
        case .reminders: .indigo
        }
    }

    /// Built and in the app. The paywall never advertises a feature that isn't (phases 4–8, courses since 2.2,
    /// schedules since 2.4, widgets and controls since 2.5). Reminders at your usual time are being built (#137,
    /// docs/pro/REMINDERS.md §6): Debug builds show their choice until they ship.
    var isShipped: Bool {
        self != .reminders
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
