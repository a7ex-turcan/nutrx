import WidgetKit

struct NutrientSnapshot {
    let id: String
    let name: String
    let unit: String
    let current: Double
    let target: Double
    let step: Double
    let goalTypeRaw: String
    let upperBound: Double?

    init(id: String, name: String, unit: String, current: Double, target: Double, step: Double, goalTypeRaw: String = "minimum", upperBound: Double? = nil) {
        self.id = id
        self.name = name
        self.unit = unit
        self.current = current
        self.target = target
        self.step = step
        self.goalTypeRaw = goalTypeRaw
        self.upperBound = upperBound
    }

    private var goalType: GoalType {
        GoalType(rawValue: goalTypeRaw) ?? .minimum
    }

    var isOnTarget: Bool {
        switch goalType {
        case .minimum: return current >= target
        case .maximum: return current <= target
        case .range:
            guard let ub = upperBound else { return current >= target }
            return current >= target && current <= ub
        }
    }

    var isExceeded: Bool {
        switch goalType {
        case .minimum: return current > target
        case .maximum: return current > target
        case .range:
            guard let ub = upperBound else { return current > target }
            return current > ub
        }
    }

    var progress: Double {
        switch goalType {
        case .minimum, .maximum:
            guard target > 0 else { return 0 }
            return current / target
        case .range:
            guard let ub = upperBound, ub > 0 else { return 0 }
            return current / ub
        }
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
