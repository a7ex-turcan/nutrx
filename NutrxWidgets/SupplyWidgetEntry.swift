import Foundation
import WidgetKit

struct SupplyWidgetEntry: TimelineEntry {
    let date: Date
    /// nil when not Pro.
    let summary: SupplyWidgetSummary?

    /// The gallery's example and the placeholder.
    static let sample = SupplyWidgetEntry(date: .now, summary: SupplyWidgetSummary(items: [
        .init(nutrientID: UUID(), name: "Omega-3", tint: .teal, symbolName: "fish", kind: .supply, isOut: true,
              daysLeft: 0),
        .init(nutrientID: UUID(), name: "Iron", tint: .coral, symbolName: "drop", kind: .course, isOut: false,
              daysLeft: 2),
        .init(nutrientID: UUID(), name: "Vitamin D", tint: .amber, symbolName: "sun.max", kind: .supply,
              isOut: false, daysLeft: 6),
        .init(nutrientID: UUID(), name: "Magnesium", tint: .indigo, symbolName: "pills", kind: .supply,
              isOut: false, daysLeft: 7),
    ], bottles: 4, courses: 1))

    static let onTrackSample = SupplyWidgetEntry(date: .now,
                                                 summary: SupplyWidgetSummary(items: [], bottles: 4, courses: 1))
    static let freeSample = SupplyWidgetEntry(date: .now, summary: nil)
}
