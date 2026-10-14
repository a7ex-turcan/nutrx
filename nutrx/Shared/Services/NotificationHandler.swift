import Foundation
import Observation
import SwiftData
import UserNotifications
import WidgetKit

/// Where a tapped notification wants to take the app. The tab bar and My Nutrients follow it: a refill reminder
/// opens that nutrient's analytics with the Supply card focused (docs/pro/design/3-supply: analytics-open).
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// The nutrient whose Supply card a refill reminder opened; cleared once it's been shown and left.
    var supplyNutrientID: UUID?
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
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.content.categoryIdentifier == Self.refillCategory ? [.banner, .list, .sound] : []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard content.categoryIdentifier == Self.refillCategory,
              let idString = content.userInfo[Self.nutrientIDKey] as? String, let id = UUID(uuidString: idString)
        else { return }
        let action = response.actionIdentifier
        await MainActor.run { handle(action: action, nutrientID: id) }
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
            WidgetCenter.shared.reloadAllTimelines()
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
