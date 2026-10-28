import Foundation
import WidgetKit

struct SupplyWidgetEntry: TimelineEntry {
    enum Content: Equatable {
        case free
        /// The shared store couldn't be opened: not the same as having nothing tracked.
        case unavailable
        case summary(SupplyWidgetSummary)
    }

    let date: Date
    let content: Content

    /// The gallery's example and the placeholder.
    static let sample = SupplyWidgetEntry(date: .now, content: .summary(SupplyWidgetSummary(items: [
        .init(nutrientID: UUID(), name: "Omega-3", tint: .teal, symbolName: "fish", kind: .supply, isOut: true,
              daysLeft: 0),
        .init(nutrientID: UUID(), name: "Iron", tint: .coral, symbolName: "drop", kind: .course, isOut: false,
              daysLeft: 2),
        .init(nutrientID: UUID(), name: "Vitamin D", tint: .amber, symbolName: "sun.max", kind: .supply,
              isOut: false, daysLeft: 6),
        .init(nutrientID: UUID(), name: "Magnesium", tint: .indigo, symbolName: "pills", kind: .supply,
              isOut: false, daysLeft: 7),
    ], bottles: 4, courses: 1)))

    /// One bottle and one course: the medium size's list rows (#301), amber and grey details.
    static let twoItemsSample = SupplyWidgetEntry(date: .now, content: .summary(SupplyWidgetSummary(items: [
        .init(nutrientID: UUID(), name: "Omega-3", tint: .teal, symbolName: "fish", kind: .supply, isOut: true,
              daysLeft: 0),
        .init(nutrientID: UUID(), name: "Iron", tint: .coral, symbolName: "drop", kind: .course, isOut: false,
              daysLeft: 1),
    ], bottles: 3, courses: 1)))

    static let onTrackSample = SupplyWidgetEntry(
        date: .now, content: .summary(SupplyWidgetSummary(items: [], bottles: 4, courses: 1)))
    static let freeSample = SupplyWidgetEntry(date: .now, content: .free)
    static let unavailableSample = SupplyWidgetEntry(date: .now, content: .unavailable)
}
