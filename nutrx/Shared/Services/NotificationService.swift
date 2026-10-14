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

    /// Refill reminders are a Pro feature: set whenever the entitlement is checked. nil until then (a cold
    /// background launch — a notification action, Siri — syncs before it), which leaves pending refill reminders
    /// and their records alone instead of treating the user as free and removing them.
    static var supplyRemindersEnabled: Bool?

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
        enqueueDailyReminderChange {
            await removePendingRequests([dailyReminderID])
            logger.info("Daily check-in cancelled")
        }
    }

    /// The latest daily check-in change, so changes apply in order: a cancel can't land after a newer schedule.
    private static var dailyReminderChange: Task<Void, Never>?

    private static func enqueueDailyReminderChange(_ change: @escaping @MainActor () async -> Void) {
        let previous = dailyReminderChange
        dailyReminderChange = Task {
            await previous?.value
            await change()
        }
    }

    /// `removePendingNotificationRequests` is synchronous and can block for minutes when the notification service
    /// is slow (#15: over two minutes right after a simulator cold boot, from Today's scene-phase handler). It runs
    /// on a private serial queue, not the main actor, and not Swift's cooperative pool either, whose few threads a
    /// hang would hold.
    private nonisolated static func removePendingRequests(_ identifiers: [String]) async {
        await withCheckedContinuation { continuation in
            notificationQueue.async {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                continuation.resume()
            }
        }
    }

    private nonisolated static let notificationQueue = DispatchQueue(label: "nutrx-labs.nutrx.notifications")

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
        // Refill reminders first: they're one per bottle, and dose reminders share what's left of the budget.
        // Unknown entitlement: keep what's pending and set aside room for it.
        // Not Pro: nothing to schedule, but the records of reminders that already fired stay, so a lapse and renewal
        // doesn't remind about the same bottle again.
        let refillPlan: RefillPlan? = supplyRemindersEnabled.map { enabled in
            enabled ? refillReminderPlan(nutrients: nutrients, now: now)
                    : RefillPlan(states: refillStates.filter { $0.value.fireDate <= now })
        }
        let refillRequests = refillPlan?.requests ?? []
        let refillReserved = refillPlan == nil
            ? refillStates.values.filter { $0.fireDate > now }.count
            : refillRequests.count
        let doseBudget = max(1, ReminderSchedule.budget - refillReserved)
        let requests = refillRequests + ReminderSchedule.occurrences(for: plans, now: now, budget: doseBudget).compactMap { occurrence in
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
                .filter {
                    ($0.hasPrefix(nutrientReminderPrefix)
                        || (refillPlan != nil && $0.hasPrefix(RefillSchedule.identifierPrefix)))
                        && !wanted.contains($0)
                }
            if !stale.isEmpty {
                await removePendingRequests(stale)
            }
            // Re-adding an identifier replaces it, so a renamed nutrient's pending reminders get the new name.
            // Adds fail while notifications aren't allowed, hence counting what was actually scheduled.
            var scheduled = 0
            var added = Set<String>()
            for request in requests where (try? await center.add(request)) != nil {
                scheduled += 1
                added.insert(request.identifier)
            }
            if let refillPlan {
                // Only what was actually added (or has already fired) is remembered, so a reminder removed before
                // it fired — Pro lapsed, notifications off — can still come for that bottle later.
                refillStates = refillPlan.states.filter { key, state in
                    state.fireDate <= now || added.contains(RefillSchedule.identifier(forKey: key))
                }
            }
            logger.info("Dose reminders synced: \(scheduled) of \(requests.count) scheduled, \(stale.count) removed")
        }
        return reminderSync
    }

    // MARK: - Refill reminders (nutrx Pro)

    private static let refillStatesKey = "nutrx.refillReminderStates"

    /// What this device has scheduled per bottle, by nutrient id (`RefillSchedule.State`).
    private static var refillStates: [String: RefillSchedule.State] {
        get {
            guard let data = UserDefaults.standard.data(forKey: refillStatesKey) else { return [:] }
            return (try? JSONDecoder().decode([String: RefillSchedule.State].self, from: data)) ?? [:]
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: refillStatesKey)
        }
    }

    /// The refill reminders a sync wants: the requests, and the per-bottle records to keep if they're added.
    struct RefillPlan {
        var requests: [UNNotificationRequest] = []
        /// By nutrient id: new or updated records, and fired ones kept so a bottle isn't reminded about twice.
        var states: [String: RefillSchedule.State] = [:]
    }

    /// One request per supply-tracked nutrient whose reminder is still to come (`RefillSchedule`).
    private static func refillReminderPlan(nutrients: [Nutrient], now: Date) -> RefillPlan {
        let previousStates = refillStates
        var plan = RefillPlan()
        for nutrient in nutrients {
            guard let status = nutrient.supplyStatus(now: now) else { continue }
            let key = nutrient.id.uuidString
            let previous = previousStates[key]
            guard let fire = RefillSchedule.fireDate(status: status, previous: previous, now: now) else {
                // Keep the record of a fired reminder for this bottle, so it doesn't come back.
                if let previous, previous.refilledAt == status.setup.refilledAt { plan.states[key] = previous }
                continue
            }
            let snoozed = previous?.refilledAt == status.setup.refilledAt && previous?.snoozed == true
            plan.states[key] = RefillSchedule.State(refilledAt: status.setup.refilledAt, fireDate: fire, snoozed: snoozed)

            let days = RefillSchedule.daysAtFire(status: status, fireDate: fire, now: now)
            let content = UNMutableNotificationContent()
            content.title = RefillSchedule.title(name: nutrient.name, daysAtFire: days, isOut: status.level == .out)
            content.body = RefillSchedule.body(daysAtFire: days, isOut: status.level == .out)
            content.sound = .default
            content.categoryIdentifier = NotificationHandler.refillCategory
            content.userInfo = [NotificationHandler.nutrientIDKey: nutrient.id.uuidString]
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            plan.requests.append(UNNotificationRequest(identifier: RefillSchedule.identifier(forKey: key),
                                                       content: content,
                                                       trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
        let summary = plan.requests.map { request in
            let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            return "\(request.content.title) @ \(date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "?")"
        }
        logger.info("Refill reminders: \(plan.requests.count) pending \(summary.joined(separator: "; "), privacy: .public)")
        return plan
    }

    /// "Remind me tomorrow": the next sync keeps this date for the bottle.
    static func snoozeRefillReminder(for nutrientID: UUID, status: SupplySchedule.Status, now: Date = .now) {
        var states = refillStates
        states[nutrientID.uuidString] = RefillSchedule.snoozed(status, now: now)
        refillStates = states
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
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in"
        content.body = "You haven't logged any intake today. Tap to start tracking!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)

        // Adding replaces a pending check-in with the same identifier, so there's no separate cancel. The async
        // `add` suspends rather than blocking the main actor.
        enqueueDailyReminderChange {
            let added = (try? await UNUserNotificationCenter.current().add(request)) != nil
            let outcome = added ? "scheduled" : "not scheduled"
            logger.info("Daily check-in \(outcome, privacy: .public) for \(date, privacy: .public)")
        }
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
