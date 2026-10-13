import BackgroundTasks
import Foundation
import os.log
import UserNotifications
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "NotificationService")

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

    /// The latest reminder sync, so a newer one runs after it: two syncs interleaving their removes and adds
    /// could leave a request the newer data doesn't want.
    private static var reminderSync: Task<Void, Never>?

    /// Background app refresh that rolls the per-date window forward when the app itself isn't opened, e.g. for
    /// someone who logs only from the Watch or widgets. Listed under `BGTaskSchedulerPermittedIdentifiers`.
    static let reminderRefreshTaskID = "nutrx-labs.nutrx.reminders"

    /// Brings the pending dose reminders in line with the data (#4): each reminder time as a one-off request per
    /// date for the next few days (`ReminderSchedule`), without the rest of today for nutrients already logged
    /// today. Call after any log change, on foreground, and after reminders or nutrients change. Requests for
    /// deleted nutrients, for times that have passed, and in the old repeating format are removed.
    @discardableResult
    static func refreshAllNutrientReminders(context: ModelContext, now: Date = .now) -> Task<Void, Never>? {
        let descriptor = FetchDescriptor<Nutrient>(predicate: #Predicate { !$0.isDeleted })
        guard let nutrients = try? context.fetch(descriptor) else { return nil }
        let totals = todayTotals(context: context, now: now)
        let withReminders = nutrients.filter { !($0.reminders ?? []).isEmpty }

        let plans = withReminders.map { nutrient in
            ReminderSchedule.Plan(
                nutrientID: nutrient.id,
                times: (nutrient.reminders ?? []).map {
                    ReminderSchedule.Time(hour: $0.timeComponents.hour, minute: $0.timeComponents.minute)
                },
                loggedToday: (totals[nutrient.persistentModelID] ?? 0) > 0
            )
        }
        let contents = Dictionary(withReminders.map { ($0.id, reminderContent(for: $0)) }) { first, _ in first }
        let requests = ReminderSchedule.occurrences(for: plans, now: now).compactMap { occurrence in
            contents[occurrence.nutrientID].map { content in
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                            from: occurrence.fireDate)
                return UNNotificationRequest(identifier: occurrence.id, content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            }
        }
        let wanted = Set(requests.map(\.identifier))
        scheduleBackgroundRefresh(needed: !requests.isEmpty)

        let previous = reminderSync
        reminderSync = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(nutrientReminderPrefix) && !wanted.contains($0) }
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            // Re-adding an identifier replaces it, so a renamed nutrient's pending reminders get the new name.
            // Adds fail while notifications aren't allowed, hence counting what was actually scheduled.
            var scheduled = 0
            for request in requests where (try? await center.add(request)) != nil {
                scheduled += 1
            }
            logger.info("Dose reminders synced: \(scheduled) of \(requests.count) scheduled, \(stale.count) removed")
        }
        return reminderSync
    }

    /// The background refresh's work: the same sync, run to completion.
    static func refreshRemindersInBackground(container: ModelContainer) async {
        await refreshAllNutrientReminders(context: container.mainContext)?.value
    }

    /// Asks iOS for a background refresh about 12 hours out while any reminders are scheduled (each sync
    /// replaces the request), or cancels it when there are none. iOS decides when it actually runs; it doesn't
    /// run with Background App Refresh off. Opening the app syncs as well, so the window only runs out after
    /// its full length (14 days for a few reminders) with neither.
    private static func scheduleBackgroundRefresh(needed: Bool) {
        guard needed else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: reminderRefreshTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: reminderRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Reminder background refresh not scheduled: \(String(describing: error), privacy: .public)")
        }
    }

    private static func reminderContent(for nutrient: Nutrient) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to log your \(nutrient.name)"
        if let notes = nutrient.notes, !notes.isEmpty {
            content.body = notes
        } else {
            content.body = "Tap to log your \(nutrient.name) intake."
        }
        content.sound = .default
        return content
    }

    /// Today's total per nutrient (the sum of today's records; it can be negative, which counts as not logged).
    private static func todayTotals(context: ModelContext, now: Date) -> [PersistentIdentifier: Double] {
        let startOfDay = Calendar.current.startOfDay(for: now)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return [:] }
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        var totals: [PersistentIdentifier: Double] = [:]
        for record in (try? context.fetch(descriptor)) ?? [] {
            if let id = record.nutrient?.persistentModelID {
                totals[id, default: 0] += record.amount
            }
        }
        return totals
    }

    // MARK: - Private Helpers

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
