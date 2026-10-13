#if DEBUG
import Foundation
import SwiftData

/// Demo data for App Store screenshots, matching the redesign renders (docs/design/screens): a morning stack and
/// a through-the-day group, three of six goals met today, a 10-day current streak (a longer best one before it),
/// and Vitamin D missed on Sundays in the weeks before the streak so the weekday pattern has something to say.
///
/// Debug builds only. Launch with `-screenshotDemoData` to replace everything in the store with it (the iPhone
/// and Watch apps both read the argument). Never runs otherwise.
enum ScreenshotDemoData {
    static let launchArgument = "-screenshotDemoData"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    /// Deletes every record in the store and inserts the demo set.
    static func replaceStore(in context: ModelContext, now: Date = .now) {
        for model in [IntakeRecord.self, NutrientReminder.self, Exclusion.self] as [any PersistentModel.Type] {
            try? context.delete(model: model)
        }
        try? context.delete(model: Nutrient.self)
        try? context.delete(model: NutrientGroup.self)
        try? context.delete(model: UserProfile.self)
        try? context.delete(model: UserPreferences.self)

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
        // it. d 12–28: Vitamin D short on Sundays and Water short every sixth day. d 29–42: every goal met (part
        // of the best streak). d 43–50: Protein under its range every other day.
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
            let waterTotal: Double = inGap && daysAgo.isMultiple(of: 6) ? 1.75 : (daysAgo.isMultiple(of: 3) ? 2.75 : 2.5)
            log(water, [0.75, 1, waterTotal - 1.75], day: day, hours: [9, 13, 18])
            let proteinTotal: Double = daysAgo > 42 && !daysAgo.isMultiple(of: 2) ? 100 : [130, 140, 150][daysAgo % 3]
            log(protein, [proteinTotal - 60, 60], day: day, hours: [12, 19])
            log(caffeine, daysAgo.isMultiple(of: 2) ? [100, 100] : [100, 200], day: day, hours: [8, 14])
        }

        // Today: three of six met (Omega-3, Magnesium, Caffeine under its limit); Vitamin D, Water and Protein to go.
        func logToday(_ item: Nutrient, _ amounts: [Double]) {
            for (index, amount) in amounts.enumerated() {
                let date = max(today, now.addingTimeInterval(TimeInterval(-60 * (index + 1) * 20)))
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
        let laterHour = min(calendar.component(.hour, from: now) + 2, 23)
        if let later = calendar.date(bySettingHour: laterHour, minute: 0, second: 0, of: today) {
            context.insert(NutrientReminder(nutrient: protein, timeOfDay: later))
        }

        try? context.save()
    }
}
#endif
