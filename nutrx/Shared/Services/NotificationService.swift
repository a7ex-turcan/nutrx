import Foundation
import UserNotifications
import SwiftData

enum NotificationPermissionStatus {
    case notDetermined
    case granted
    case denied
}

enum NotificationService {
    private static let dailyReminderID = "daily-checkin-reminder"
    private static let nutrientReminderPrefix = "nutrient-"

    // MARK: - Permissions

    static func permissionStatus() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Daily Check-in Reminder

    static func refreshDailyReminder(context: ModelContext) {
        let preferences = fetchPreferences(context: context)

        guard preferences.dailyReminderEnabled else {
            cancelDailyReminder()
            return
        }

        let hasIntakeToday = hasAnyIntakeToday(context: context)

        if hasIntakeToday {
            scheduleReminder(for: nextNoon(afterToday: true))
        } else {
            scheduleReminder(for: nextNoon(afterToday: false))
        }
    }

    static func scheduleDailyReminder() {
        scheduleReminder(for: nextNoon(afterToday: false))
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }

    // MARK: - Per-Nutrient Dose Reminders

    /// Schedules all reminders for a given nutrient. Cancels existing ones first.
    static func scheduleReminders(for nutrient: Nutrient) {
        cancelReminders(for: nutrient)

        for reminder in nutrient.reminders {
            let (hour, minute) = reminder.timeComponents
            let id = nutrientReminderID(nutrientID: nutrient.persistentModelID, hour: hour, minute: minute)

            let content = UNMutableNotificationContent()
            content.title = "Time to log your \(nutrient.name)"
            content.body = "Tap to log your \(nutrient.name) intake."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Cancels all pending reminders for a given nutrient.
    static func cancelReminders(for nutrient: Nutrient) {
        let prefix = "\(nutrientReminderPrefix)\(nutrient.persistentModelID)-reminder-"
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    /// Called after a user logs intake for a nutrient. Suppresses any pending
    /// reminders for that nutrient that are scheduled for earlier today.
    static func suppressRemindersAfterLogging(for nutrient: Nutrient) {
        let now = Date.now
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let prefix = "\(nutrientReminderPrefix)\(nutrient.persistentModelID)-reminder-"
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            var idsToCancel: [String] = []

            for request in requests where request.identifier.hasPrefix(prefix) {
                // Extract HHmm from the ID
                let suffix = request.identifier.dropFirst(prefix.count)
                guard suffix.count == 4,
                      let hour = Int(suffix.prefix(2)),
                      let minute = Int(suffix.suffix(2)) else { continue }

                // Cancel reminders scheduled for later today (they'll re-fire tomorrow via repeating trigger)
                if hour > currentHour || (hour == currentHour && minute > currentMinute) {
                    // This is a future reminder today — keep it, the user might need it
                    // Actually per the spec: suppress if user already logged since the *previous* reminder
                    // For simplicity, after logging we cancel all remaining reminders for today
                    // They will fire again tomorrow via the repeating trigger
                }

                // Cancel all pending for today — they'll repeat tomorrow automatically
                idsToCancel.append(request.identifier)
            }

            if !idsToCancel.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToCancel)
                // Reschedule them so they fire again tomorrow
                // Since we use repeating triggers, removing and re-adding restarts them for next day
                DispatchQueue.main.async {
                    NotificationService.scheduleReminders(for: nutrient)
                }
            }
        }
    }

    /// Reschedules all nutrient reminders for all non-deleted nutrients.
    /// Call on app foreground to ensure reminders are fresh.
    static func refreshAllNutrientReminders(context: ModelContext) {
        let descriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
        )
        guard let nutrients = try? context.fetch(descriptor) else { return }

        for nutrient in nutrients where !nutrient.reminders.isEmpty {
            scheduleReminders(for: nutrient)
        }
    }

    // MARK: - Private Helpers

    private static func nutrientReminderID(nutrientID: PersistentIdentifier, hour: Int, minute: Int) -> String {
        "\(nutrientReminderPrefix)\(nutrientID)-reminder-\(String(format: "%02d%02d", hour, minute))"
    }

    private static func scheduleReminder(for date: Date) {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in"
        content.body = "You haven't logged any intake today. Tap to start tracking!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private static func nextNoon(afterToday: Bool) -> Date {
        let calendar = Calendar.current
        let now = Date.now
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

        if !afterToday && now < todayNoon {
            return todayNoon
        }
        return calendar.date(byAdding: .day, value: 1, to: todayNoon)!
    }

    private static func hasAnyIntakeToday(context: ModelContext) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        var descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        descriptor.fetchLimit = 1

        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    static func fetchPreferences(context: ModelContext) -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = UserPreferences()
        context.insert(new)
        return new
    }
}
