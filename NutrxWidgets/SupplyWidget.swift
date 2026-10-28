import SwiftUI
import WidgetKit

// What's running out or ending (nutrx Pro, #138, docs/pro/WIDGETS.md §4): supply that's low or out and courses near
// their last day, soonest first (`SupplyWidgetSummary`). Static: nothing to configure.

struct NutrxSupplyWidget: Widget {
    static let kind = "NutrxSupplyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SupplyWidgetProvider()) { entry in
            SupplyWidgetView(entry: entry)
        }
        .configurationDisplayName("Supply and courses")
        .description("What's running low or ending soon, soonest first.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct SupplyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SupplyWidgetEntry

    var body: some View {
        if family == .accessoryRectangular {
            SupplyRectangularWidgetView(content: entry.content)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(link.url)
        } else {
            SupplyListWidgetView(content: entry.content, isMedium: family == .systemMedium)
                .containerBackground(Theme.surfaceCard, for: .widget)
                .widgetURL(link.url)
        }
    }

    /// The paywall when free; else the first item's analytics, or My Nutrients with nothing listed. The medium
    /// size's rows are links of their own.
    private var link: AppLink {
        switch entry.content {
        case .free: .pro
        case .unavailable: .today
        case .summary(let summary): summary.items.first.map { .nutrient($0.nutrientID) } ?? .nutrients
        }
    }
}

#Preview("Small", as: .systemSmall) {
    NutrxSupplyWidget()
} timeline: {
    SupplyWidgetEntry.sample
    SupplyWidgetEntry.onTrackSample
    SupplyWidgetEntry.freeSample
    SupplyWidgetEntry.unavailableSample
}

#Preview("Medium", as: .systemMedium) {
    NutrxSupplyWidget()
} timeline: {
    SupplyWidgetEntry.sample
    SupplyWidgetEntry.twoItemsSample
    SupplyWidgetEntry.onTrackSample
    SupplyWidgetEntry.freeSample
    SupplyWidgetEntry.unavailableSample
}
