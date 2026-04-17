import SwiftUI
import SwiftData
import WidgetKit

@main
struct nutrxWatchApp: App {
    let modelContainer: ModelContainer

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = ModelContainerFactory.create()
        #if DEBUG
        Self.seedSampleDataIfEmpty(container: container)
        #endif
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    #if DEBUG
    @MainActor
    private static func seedSampleDataIfEmpty(container: ModelContainer) {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<Nutrient>())) ?? 0
        guard count == 0 else { return }

        // Groups
        let vitamins = NutrientGroup(name: "Vitamins", sortOrder: 0)
        let supplements = NutrientGroup(name: "Supplements", sortOrder: 1)
        let general = NutrientGroup(name: "General", sortOrder: Int.max, isSystem: true)
        context.insert(vitamins)
        context.insert(supplements)
        context.insert(general)

        // (name, unit, step, target, groupSortOrder, goalType, upperBound, group, intake)
        let sampleData: [(String, String, Double, Double, Int, GoalType, Double?, NutrientGroup, Double)] = [
            ("Vitamin D",  "IU",   1000, 4000, 0, .minimum, nil,  vitamins,     3000),
            ("Vitamin C",  "mg",   250,  1000, 1, .minimum, nil,  vitamins,     1000),
            ("Omega-3",    "mg",   500,  2000, 0, .minimum, nil,  supplements,  2000),
            ("Protein",    "g",    10,   150,  1, .minimum, nil,  supplements,  80),
            ("Water",      "cups", 1,    8,    0, .minimum, nil,  general,      5),
            ("Caffeine",   "mg",   100,  400,  1, .maximum, nil,  general,      200),
            ("Sodium",     "mg",   500,  2300, 2, .range,   3500, general,      2500),
        ]

        for (sortOrder, entry) in sampleData.enumerated() {
            let nutrient = Nutrient(name: entry.0, unit: entry.1, step: entry.2, dailyTarget: entry.3, sortOrder: sortOrder)
            nutrient.goalType = entry.5
            nutrient.upperBound = entry.6
            nutrient.group = entry.7
            nutrient.groupSortOrder = entry.4
            context.insert(nutrient)

            var remaining = entry.8
            while remaining > 0 {
                let amount = min(entry.2, remaining)
                context.insert(IntakeRecord(nutrient: nutrient, amount: amount))
                remaining -= amount
            }
        }

        try? context.save()
    }
    #endif
}
