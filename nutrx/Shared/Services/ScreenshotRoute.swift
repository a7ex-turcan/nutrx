#if DEBUG
import Foundation

/// Debug builds only: `-screenshotRoute <route>` opens the app on a screen, so a screenshot needs no tapping (#218),
/// e.g. on the iPhone Duo's inner display, which the device-interaction tools can't reach. With `-screenshotDemoData`:
/// `xcrun simctl launch <UDID> nutrx-labs.nutrx -screenshotDemoData -screenshotRoute "nutrients/Vitamin D"`.
///
/// Routes: `today`, `nutrients`, `stacks`, `history` (a tab); `nutrients/<name>` (that nutrient's analytics, by name,
/// ignoring case); `history/<yyyy-MM-dd>` (that day); `paywall` (over Today). An unknown name or day opens the tab.
/// `NotificationRouter.screenshotRoute` carries it to the screens, the way a tapped notification's route does.
enum ScreenshotRoute: Equatable {
    case today, nutrients, stacks, history
    case nutrient(name: String)
    case historyDay(Date)
    case paywall

    static let launchArgument = "-screenshotRoute"

    /// The route after the launch argument, if there is one and it reads.
    static var requested: ScreenshotRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: launchArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return parse(arguments[index + 1])
    }

    static func parse(_ value: String, calendar: Calendar = .current) -> ScreenshotRoute? {
        let parts = value.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first?.lowercased() else { return nil }
        let rest = parts.count > 1 ? parts[1] : ""
        switch (first, rest.isEmpty) {
        case ("today", true): return .today
        case ("nutrients", true): return .nutrients
        case ("nutrients", false): return .nutrient(name: rest)
        case ("stacks", true): return .stacks
        case ("history", true): return .history
        // A day that doesn't read still opens History, as an unknown nutrient name opens My Nutrients.
        case ("history", false): return day(rest, calendar: calendar).map(ScreenshotRoute.historyDay) ?? .history
        case ("paywall", true): return .paywall
        default: return nil
        }
    }

    /// "2026-10-20" as the start of that day.
    private static func day(_ string: String, calendar: Calendar) -> Date? {
        let numbers = string.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3,
              let date = calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])),
              // Not a day that doesn't exist ("2026-02-30" would otherwise roll over into March).
              calendar.dateComponents([.year, .month, .day], from: date)
                == DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
        else { return nil }
        return date
    }
}
#endif
