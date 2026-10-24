import AppIntents

/// The screens a control can open (#138).
enum AppScreen: String, AppEnum {
    case today
    case nutrients
    case pro

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    static let caseDisplayRepresentations: [AppScreen: DisplayRepresentation] = [
        .today: "Today",
        .nutrients: "My Nutrients",
        .pro: "nutrx Pro",
    ]

    var link: AppLink {
        switch self {
        case .today: .today
        case .nutrients: .nutrients
        case .pro: .pro
        }
    }
}

/// Opens the app on a screen: what a control's tap returns when it can't log (free, nothing chosen, gone; #138,
/// docs/pro/WIDGETS.md §2). An `OpenIntent` runs in the app, which it opens. `OpenURLIntent` doesn't do here: it
/// takes universal links, and a control handed it `nutrx://pro` opened nothing. Compiled into the app and the widget
/// extension: the extension builds it, the app performs it.
struct OpenNutrxIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open nutrx"
    /// The controls' only.
    static let isDiscoverable = false

    /// How the app follows the link; set by `nutrxApp` at launch (the extension can't see `NotificationRouter`).
    static var openLink: ((AppLink) -> Void)?

    @Parameter(title: "Screen")
    var target: AppScreen

    init() {}

    init(_ screen: AppScreen) {
        target = screen
    }

    func perform() async throws -> some IntentResult {
        Self.openLink?(target.link)
        return .result()
    }
}
