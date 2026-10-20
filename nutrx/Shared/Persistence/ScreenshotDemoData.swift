#if DEBUG
import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "ScreenshotDemoData")

/// Demo data for App Store screenshots, matching the redesign renders (docs/design/screens): a morning stack and
/// a through-the-day group, three of six goals met today, a 10-day current streak (a longer best one before it),
/// and Vitamin D missed on Sundays in the weeks before the streak so the weekday pattern has something to say.
///
/// Debug builds only. Launch with `-screenshotDemoData` to replace everything in the store with it (the iPhone
/// and Watch apps both read the argument). Never runs otherwise. **Use simulators signed out of iCloud:** the store
/// is CloudKit-backed, so on a device signed in it also deletes that account's development-container data on every
/// synced device.
enum ScreenshotDemoData {
    static let launchArgument = "-screenshotDemoData"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    /// Deletes every record in the store and inserts the demo set.
    static func replaceStore(in context: ModelContext, now: Date = .now) {
        // Children first. A failed delete would leave the demo set on top of the old data, so say so.
        let models: [any PersistentModel.Type] = [IntakeRecord.self, NutrientReminder.self, Exclusion.self,
                                                  LogStackEntry.self, LogStack.self,
                                                  Nutrient.self, NutrientGroup.self, UserProfile.self,
                                                  UserPreferences.self]
        for model in models {
            do {
                try context.delete(model: model)
            } catch {
                logger.error("Couldn't clear \(String(describing: model), privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let created = calendar.date(byAdding: .day, value: -50, to: today) ?? today

        let profile = UserProfile(name: "Alex", birthdate: .distantPast, weight: 0, height: 0, onboardingCompleted: true)
        profile.createdAt = created
        context.insert(profile)
        context.insert(UserPreferences(hasSeenNotificationBanner: true, hasSeenSyncRestoredBanner: true,
                                       hasSeenSyncEnabledBanner: true))

        let morning = NutrientGroup(name: "Morning stack", sortOrder: 0)
        let daytime = NutrientGroup(name: "Through the day", sortOrder: 1)
        context.insert(morning)
        context.insert(daytime)
        context.insert(NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true))

        func nutrient(_ name: String, _ unit: String, step: Double, target: Double, goal: GoalType = .minimum,
                      upper: Double? = nil, tint: NutrientTint, symbol: String, group: NutrientGroup,
                      order: Int) -> Nutrient {
            let item = Nutrient(name: name, unit: unit, step: step, dailyTarget: target, sortOrder: order,
                                goalType: goal, upperBound: upper)
            item.tint = tint
            item.symbolName = symbol
            item.group = group
            item.groupSortOrder = order
            item.createdAt = created
            context.insert(item)
            return item
        }

        let vitaminD = nutrient("Vitamin D", "IU", step: 1000, target: 4000, tint: .amber, symbol: "sun.max",
                                group: morning, order: 0)
        let omega3 = nutrient("Omega-3", "mg", step: 500, target: 2000, tint: .teal, symbol: "fish",
                              group: morning, order: 1)
        let magnesium = nutrient("Magnesium", "mg", step: 200, target: 400, tint: .indigo, symbol: "pills",
                                 group: morning, order: 2)
        let water = nutrient("Water", "L", step: 0.25, target: 2.5, tint: .blue, symbol: "drop",
                             group: daytime, order: 0)
        let protein = nutrient("Protein", "g", step: 20, target: 120, goal: .range, upper: 160, tint: .coral,
                               symbol: "dumbbell", group: daytime, order: 1)
        let caffeine = nutrient("Caffeine", "mg", step: 100, target: 400, goal: .maximum, tint: .brown,
                                symbol: "cup.and.saucer", group: daytime, order: 2)

        func log(_ item: Nutrient, _ amounts: [Double], day: Date, hours: [Int]) {
            for (amount, hour) in zip(amounts, hours) where amount > 0 {
                let date = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
                context.insert(IntakeRecord(nutrient: item, amount: amount, date: date))
            }
        }

        // Past days, newest first. d 1–10: every goal met (the current streak). d 11: Vitamin D short, which ends
        // it. d 12–28: Vitamin D short on Sundays, and Water short on d 12 and d 20. d 29–42: every goal met (part
        // of the best streak). d 43–50: Protein under its range every other day.
        // The recap's "day you tend to miss" needs Sunday missed more often than any other weekday in the four weeks
        // it looks at, which can hold only two of those Sundays (Monday to Wednesday). So the other misses (d 11, 12,
        // 20) are on three different weekdays: d 11 and a d 18 used to share one and tied with Sunday (#164).
        for daysAgo in 1...50 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let inGap = (11...28).contains(daysAgo)

            let vitaminDAmount: Double = daysAgo == 11 ? 3000
                : inGap && weekday == 1 ? 2000 : (weekday == 6 ? 5000 : 4000)
            log(vitaminD, vitaminDAmount >= 4000 ? [3000, vitaminDAmount - 3000] : [vitaminDAmount],
                day: day, hours: [8, 13])
            log(omega3, daysAgo.isMultiple(of: 4) ? [1000, 1500] : [1000, 1000], day: day, hours: [8, 20])
            log(magnesium, [400], day: day, hours: [21])
            let waterTotal: Double = [12, 20].contains(daysAgo) ? 1.75 : (daysAgo.isMultiple(of: 3) ? 2.75 : 2.5)
            log(water, [0.75, 1, waterTotal - 1.75], day: day, hours: [9, 13, 18])
            let proteinTotal: Double = daysAgo > 42 && !daysAgo.isMultiple(of: 2) ? 100 : [130, 140, 150][daysAgo % 3]
            log(protein, [proteinTotal - 60, 60], day: day, hours: [12, 19])
            log(caffeine, daysAgo.isMultiple(of: 2) ? [100, 100] : [100, 200], day: day, hours: [8, 14])
        }

        // Today: three of six met (Omega-3, Magnesium, Caffeine under its limit); Vitamin D, Water and Protein to go.
        // Logged by 9:30 at the latest, so the log sheet's times fit the 9:41 status bar of the captures.
        let morning930 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today) ?? now
        let todayBase = min(now, morning930)
        func logToday(_ item: Nutrient, _ amounts: [Double]) {
            for (index, amount) in amounts.enumerated() {
                let date = max(today, todayBase.addingTimeInterval(TimeInterval(-60 * (index + 1) * 20)))
                context.insert(IntakeRecord(nutrient: item, amount: amount, date: date))
            }
        }
        logToday(vitaminD, [1000, 1000])
        logToday(omega3, [1000, 1000])
        logToday(magnesium, [400])
        logToday(water, [0.75, 0.75])
        logToday(caffeine, [100, 100])

        // Reminders: Vitamin D at 13:00 (its analytics row), Protein a couple of hours from now, so the day-score
        // card has a "next reminder" line (Protein has nothing logged today).
        if let oneOClock = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) {
            context.insert(NutrientReminder(nutrient: vitaminD, timeOfDay: oneOClock))
        }
        // Late in the evening that would pass midnight: 23:59 is still ahead of anything before it.
        let laterHour = calendar.component(.hour, from: now) + 2
        if let later = laterHour > 23
            ? calendar.date(bySettingHour: 23, minute: 59, second: 0, of: today)
            : calendar.date(bySettingHour: laterHour, minute: 0, second: 0, of: today) {
            context.insert(NutrientReminder(nutrient: protein, timeOfDay: later))
        }

        // Stacks: the morning three (not logged today) and an evening pair.
        let morningStack = LogStack(name: "Morning", sortOrder: 0)
        let daytimeStack = LogStack(name: "Through the day", sortOrder: 1)
        context.insert(morningStack)
        context.insert(daytimeStack)
        for (stack, items) in [(morningStack, [(vitaminD, 2000.0), (omega3, 1000), (magnesium, 400)]),
                               (daytimeStack, [(water, 0.5), (protein, 40)])] {
            for (order, item) in items.enumerated() {
                let entry = LogStackEntry(nutrient: item.0, amount: item.1, sortOrder: order)
                context.insert(entry)
                entry.stack = stack
            }
        }

        try? context.save()

        #if os(iOS)
        // Supply (nutrx Pro): Vitamin D running low, Omega-3 out, Magnesium with plenty left. The bottle sizes are
        // worked out from the demo's own log, so the states hold whatever the history looks like.
        func setSupply(_ item: Nutrient, refilledDaysAgo: Int, daysLeft: Double) {
            let refilled = calendar.date(byAdding: .day, value: -refilledDaysAgo, to: calendar.startOfDay(for: now))!
            let logs = (item.intakeRecords ?? []).map { SupplySchedule.Log(date: $0.date, amount: $0.amount) }
            let used = logs.filter { $0.date >= refilled && $0.date <= now }.reduce(0) { $0 + $1.amount }
            let daily = SupplySchedule.averageDailyUse(logs: logs, now: now, calendar: calendar) ?? item.dailyTarget
            item.supplyRefilledAt = refilled
            let servings = (used + daily * daysLeft) / item.effectiveServingAmount
            item.supplyServings = max(1, daysLeft == 0 ? servings.rounded(.down) : servings.rounded(.up))
        }
        setSupply(vitaminD, refilledDaysAgo: 40, daysLeft: 6)
        setSupply(omega3, refilledDaysAgo: 30, daysLeft: 0)
        setSupply(magnesium, refilledDaysAgo: 10, daysLeft: 50)
        try? context.save()
        #endif
    }
}
#endif
