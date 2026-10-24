import Foundation
import Observation
import SwiftData
import UserNotifications

/// Where a tapped notification wants to take the app. The tab bar and My Nutrients follow it: a refill reminder
/// opens that nutrient's analytics with the Supply card focused (docs/pro/design/3-supply: analytics-open).
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// The nutrient whose Supply card a refill reminder opened; cleared once it's been shown and left.
    var supplyNutrientID: UUID?
    /// A recap notification was tapped: History opens the weekly recap, then clears it.
    var showsRecap = false
    /// Today's stacks row asked for the Stacks tab (Edit); the tab bar switches and clears it.
    var showsStacks = false
    /// Today's Apple Health card asked to see where insights appear (#102): Nutrients pushes that nutrient's analytics,
    /// which scrolls to its With Apple Health card, then clears it.
    var healthNutrientID: UUID?
    /// A widget opened a nutrient (`nutrx://nutrients/<id>`): Nutrients shows its analytics, then clears it.
    var nutrientID: UUID?
    /// A Pro widget or control tapped by a free user (`nutrx://pro`): Today opens the paywall, then clears it.
    var showsPaywall = false
    /// A widget asked for a tab (`nutrx://today`, `nutrx://nutrients`): the tab bar switches, then clears it.
    var linkedTab: LinkedTab?

    enum LinkedTab { case today, nutrients }

    /// Follows a widget's or control's link (docs/pro/WIDGETS.md §5).
    func open(_ link: AppLink) {
        switch link {
        case .today: linkedTab = .today
        case .nutrients: linkedTab = .nutrients
        case .nutrient(let id): nutrientID = id
        case .pro: showsPaywall = true
        }
    }
    #if DEBUG
    /// `-screenshotRoute` (#218): the tab bar switches, and My Nutrients, History or Today open what it names.
    var screenshotRoute: ScreenshotRoute?
    #endif
}

/// The app's notification delegate: refill reminder actions (Refilled, Remind me tomorrow) and taps. Dose and
/// check-in reminders behave as before (no banner while the app is open, a tap just opens it).
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    static let refillCategory = "nutrx.refill"
    static let refilledAction = "nutrx.refill.refilled"
    static let snoozeAction = "nutrx.refill.snooze"
    static let nutrientIDKey = "nutrientID"

    /// The app's container, set at launch (actions run in the app's process, sometimes in the background).
    nonisolated(unsafe) var container: ModelContainer?

    /// Refilled (runs in the background, no app launch needed) and Remind me tomorrow.
    static func registerCategories() {
        let refilled = UNNotificationAction(identifier: refilledAction, title: "Refilled",
                                            icon: UNNotificationActionIcon(systemImageName: "arrow.clockwise"))
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Remind me tomorrow",
                                          icon: UNNotificationActionIcon(systemImageName: "clock"))
        let category = UNNotificationCategory(identifier: refillCategory, actions: [refilled, snooze],
                                              intentIdentifiers: [])
        // The recap: tapping opens it; "Turn off weekly recaps" does what the Settings switch does.
        let turnOff = UNNotificationAction(identifier: RecapSchedule.turnOffAction, title: "Turn off weekly recaps",
                                           icon: UNNotificationActionIcon(systemImageName: "bell.slash"))
        let recap = UNNotificationCategory(identifier: RecapSchedule.category, actions: [turnOff], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category, recap])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let category = notification.request.content.categoryIdentifier
        return category == Self.refillCategory || category == RecapSchedule.category ? [.banner, .list, .sound] : []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        if content.categoryIdentifier == RecapSchedule.category {
            let action = response.actionIdentifier
            await MainActor.run { handleRecap(action: action) }
            return
        }
        guard content.categoryIdentifier == Self.refillCategory,
              let idString = content.userInfo[Self.nutrientIDKey] as? String, let id = UUID(uuidString: idString)
        else { return }
        let action = response.actionIdentifier
        // The action may have launched the app in the background: know whether refill reminders are on before
        // the resync it triggers.
        if NotificationService.supplyRemindersEnabled == nil {
            let isPro = await ProEntitlement.current() != nil
            await MainActor.run { NotificationService.supplyRemindersEnabled = ProAccess.isStoreVisible && isPro }
        }
        await MainActor.run { handle(action: action, nutrientID: id) }
    }

    @MainActor
    private func handleRecap(action: String) {
        switch action {
        case RecapSchedule.turnOffAction:
            UserDefaults.standard.set(false, forKey: RecapSchedule.enabledKey)
            if let context = container?.mainContext { NotificationService.refreshAllNutrientReminders(context: context) }
        case UNNotificationDismissActionIdentifier:
            break
        default:
            NotificationRouter.shared.showsRecap = true
        }
    }

    @MainActor
    private func handle(action: String, nutrientID: UUID) {
        guard let context = container?.mainContext else { return }
        let descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { $0.id == nutrientID })
        guard let nutrient = try? context.fetch(descriptor).first else { return }
        switch action {
        case Self.refilledAction:
            nutrient.refillSupply()
            try? context.save()
            NotificationService.refreshAllNutrientReminders(context: context)
            WidgetReload.all()
            // Today patches totals in place; this makes it reload (the same note Siri logging posts).
            NotificationCenter.default.post(name: .intakeLoggedByShortcut, object: nil)
        case Self.snoozeAction:
            if let status = nutrient.supplyStatus() {
                NotificationService.snoozeRefillReminder(for: nutrient.id, status: status)
                NotificationService.refreshAllNutrientReminders(context: context)
            }
        default:
            NotificationRouter.shared.supplyNutrientID = nutrient.id
        }
    }
}
