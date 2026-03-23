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
        let center = UNUserNotificationCenter.current()
        let prefix = "\(nutrientReminderPrefix)\(nutrient.persistentModelID)-reminder-"

        // Collect the IDs we're about to schedule so we can cancel stale ones synchronously
        var newIDs: Set<String> = []
        var requests: [UNNotificationRequest] = []

        for reminder in nutrient.reminders {
            let (hour, minute) = reminder.timeComponents
            let id = nutrientReminderID(nutrientID: nutrient.persistentModelID, hour: hour, minute: minute)
            newIDs.insert(id)

            let content = UNMutableNotificationContent()
            content.title = "Time to log your \(nutrient.name)"
            if let notes = nutrient.notes, !notes.isEmpty {
                content.body = notes
            } else {
                content.body = "Tap to log your \(nutrient.name) intake."
            }
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        // Remove all existing reminders for this nutrient, then add new ones.
        // Using getPendingNotificationRequests async overload ensures cancel completes before scheduling.
        Task {
            let pending = await center.pendingNotificationRequests()
            let staleIDs = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) && !newIDs.contains($0) }
            if !staleIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: staleIDs)
            }

            for request in requests {
                try? await center.add(request)
            }
        }
    }

    /// Cancels all pending reminders for a given nutrient.
    static func cancelReminders(for nutrient: Nutrient) {
        let prefix = "\(nutrientReminderPrefix)\(nutrient.persistentModelID)-reminder-"
        let center = UNUserNotificationCenter.current()

        Task {
            let pending = await center.pendingNotificationRequests()
            let ids = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    /// Called after a user logs intake for a nutrient. Suppresses any pending
    /// reminders for that nutrient scheduled for later today, then reschedules
    /// them so they fire again tomorrow.
    static func suppressRemindersAfterLogging(for nutrient: Nutrient) {
        let prefix = "\(nutrientReminderPrefix)\(nutrient.persistentModelID)-reminder-"
        let center = UNUserNotificationCenter.current()

        Task {
            let pending = await center.pendingNotificationRequests()
            let idsToCancel = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }

            if !idsToCancel.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToCancel)
                // Reschedule so they fire again tomorrow (repeating triggers restart on re-add)
                scheduleReminders(for: nutrient)
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
