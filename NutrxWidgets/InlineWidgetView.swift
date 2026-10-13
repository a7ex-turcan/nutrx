import WidgetKit
import SwiftUI

struct NutrxInlineWidget: Widget {
    let kind = "NutrxInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            InlineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Goals and streak")
        .description("Goals met today and your streak, above the clock.")
        .supportedFamilies([.accessoryInline])
    }
}

/// "3/6 goals · 10-day streak" (DESIGN.md §5.10).
struct InlineWidgetView: View {
    let entry: NutrxWidgetEntry

    private var allMet: Bool { entry.totalCount > 0 && entry.metCount == entry.totalCount }

    var body: some View {
        let text = WidgetSummary.inline(met: entry.metCount, total: entry.totalCount,
                                        streakDays: entry.currentStreak, streaksEnabled: entry.streaksEnabled)
        Label(text, systemImage: allMet ? "checkmark.circle" : "circle.dashed")
            .accessibilityLabel(text)  // the text alone; the icon would read as "Selected"
            .widgetURL(URL(string: "nutrx://today"))
    }
}

#Preview("Inline", as: .accessoryInline) {
    NutrxInlineWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
}
