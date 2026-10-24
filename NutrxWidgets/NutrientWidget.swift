import SwiftUI
import WidgetKit

// One nutrient on the Home Screen and the Lock Screen (nutrx Pro, #138, docs/pro/WIDGETS.md §3): its ring, value and
// status with a + on the small size, a ring on the Lock Screen. What it shows comes from `NutrientWidgetContent`.

struct NutrxNutrientWidget: Widget {
    static let kind = "NutrxNutrientWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NutrientWidgetConfiguration.self,
                               provider: NutrientWidgetProvider()) { entry in
            NutrientWidgetView(content: entry.content)
        }
        .configurationDisplayName("Nutrient")
        .description("One nutrient you choose: today's progress, and + to log it on the Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct NutrientWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let content: NutrientWidgetContent

    var body: some View {
        if family == .accessoryCircular {
            NutrientRingWidgetView(content: content)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(link.url)
        } else {
            NutrientSmallWidgetView(content: content)
                .containerBackground(Theme.surfaceCard, for: .widget)
                .widgetURL(link.url)
        }
    }

    /// The paywall when free, My Nutrients to pick one, else that nutrient's analytics.
    private var link: AppLink {
        switch content {
        case .free: .pro
        case .choose: .nutrients
        case .nutrient(let shown): .nutrient(shown.id)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    NutrxNutrientWidget()
} timeline: {
    NutrientWidgetEntry.sample
    NutrientWidgetEntry(date: .now, content: .nutrient(.init(
        id: UUID(), name: "Magnesium", tint: .indigo, symbolName: "pills",
        status: .due(GoalProgress(current: 400, goalType: .minimum, target: 400, upperBound: nil, unit: "mg")))))
    NutrientWidgetEntry(date: .now, content: .nutrient(.init(
        id: UUID(), name: "Vitamin B12", tint: .coral, symbolName: "capsule",
        status: .notToday(next: "Next: Sunday"))))
    NutrientWidgetEntry(date: .now, content: .choose)
    NutrientWidgetEntry(date: .now, content: .free)
}
