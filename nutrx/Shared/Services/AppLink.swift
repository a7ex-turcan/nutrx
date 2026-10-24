import Foundation

/// A link into the app from a widget or control tap (`widgetURL`, docs/pro/WIDGETS.md §5): `nutrx://today`,
/// `nutrx://nutrients`, `nutrx://nutrients/<uuid>` (that nutrient's analytics) or `nutrx://pro` (the paywall over
/// Today). Compiled into the widget extension too, which builds the links. `NotificationRouter.open(_:)` follows them.
enum AppLink: Equatable {
    case today
    case nutrients
    case nutrient(UUID)
    case pro

    static let scheme = "nutrx"

    /// The link a URL names; nil for anything else (the app then opens Today).
    init?(_ url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        switch (host, path.count) {
        case ("today", 0): self = .today
        case ("nutrients", 0): self = .nutrients
        case ("nutrients", 1):
            guard let id = UUID(uuidString: path[0]) else { return nil }
            self = .nutrient(id)
        case ("pro", 0): self = .pro
        default: return nil
        }
    }

    var url: URL {
        switch self {
        case .today: URL(string: "nutrx://today")!
        case .nutrients: URL(string: "nutrx://nutrients")!
        case .nutrient(let id): URL(string: "nutrx://nutrients/\(id.uuidString)")!
        case .pro: URL(string: "nutrx://pro")!
        }
    }
}
