import WidgetKit

struct NutrientSnapshot {
    let id: String
    let name: String
    let unit: String
    let current: Double
    let target: Double
    let step: Double

    var isOnTarget: Bool { current >= target }
    var isExceeded: Bool { current > target }
    var progress: Double {
        guard target > 0 else { return 0 }
        return current / target
    }
}

struct NutrxWidgetEntry: TimelineEntry {
    let date: Date
    let nutrients: [NutrientSnapshot]
    let isPlaceholder: Bool
    let currentStreak: Int
    let streaksEnabled: Bool

    var completedCount: Int { nutrients.filter(\.isOnTarget).count }
    var totalCount: Int { nutrients.count }

    static var placeholder: NutrxWidgetEntry {
        NutrxWidgetEntry(
            date: .now,
            nutrients: [
                NutrientSnapshot(id: "", name: "Vitamin D", unit: "IU", current: 2000, target: 4000, step: 1000),
                NutrientSnapshot(id: "", name: "Omega-3", unit: "mg", current: 1500, target: 2000, step: 500),
                NutrientSnapshot(id: "", name: "Magnesium", unit: "mg", current: 400, target: 400, step: 200),
            ],
            isPlaceholder: true,
            currentStreak: 12,
            streaksEnabled: true
        )
    }
}
