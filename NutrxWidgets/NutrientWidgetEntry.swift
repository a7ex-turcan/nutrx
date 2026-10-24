import Foundation
import WidgetKit

struct NutrientWidgetEntry: TimelineEntry {
    let date: Date
    let content: NutrientWidgetContent

    /// The gallery's example and the placeholder: Vitamin D halfway.
    static let sample = NutrientWidgetEntry(date: .now, content: .nutrient(.init(
        id: UUID(), name: "Vitamin D", tint: .amber, symbolName: "sun.max",
        status: .due(GoalProgress(current: 2000, goalType: .minimum, target: 4000, upperBound: nil, unit: "IU")))))
}
