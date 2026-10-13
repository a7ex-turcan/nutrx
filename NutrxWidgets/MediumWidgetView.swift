import WidgetKit
import SwiftUI
import AppIntents

struct NutrxMediumWidget: Widget {
    let kind = "NutrxMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(Theme.surfaceCard, for: .widget)
        }
        .configurationDisplayName("Quick log")
        .description("Log your nutrients without opening the app.")
        // Small and large stay supported so widgets people already placed keep working.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Rows of ring + name + value + interactive "+" (DESIGN.md §5.10): 3 in medium, 2 in small, 6 in large.
struct MediumWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NutrxWidgetEntry

    private var rowLimit: Int {
        switch family {
        case .systemSmall: 2
        case .systemLarge: 6
        default: 3
        }
    }

    var body: some View {
        if entry.totalCount == 0 {
            VStack(spacing: 6) {
                Image(systemName: "leaf")
                    .font(.title2)
                    .foregroundStyle(Theme.green)
                Text("Add a nutrient in nutrx")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .widgetURL(URL(string: "nutrx://nutrients"))
        } else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 14 : 6) {
                if family == .systemLarge {
                    header
                }
                ForEach(entry.nutrients.prefix(rowLimit)) { nutrient in
                    WidgetNutrientRow(nutrient: nutrient, compact: family == .systemSmall)
                }
                if family == .systemLarge {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity, alignment: family == .systemLarge ? .top : .center)
            .widgetURL(URL(string: "nutrx://today"))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(WidgetSummary.score(met: entry.metCount, total: entry.totalCount)) goals")
                .font(.subheadline.weight(.semibold)).fontDesign(.rounded)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 2)
    }
}

/// A nutrient's ring in its tint, its name and value, and a "+" that logs one step via `LogNutrientIntent`.
/// The small family has no room for a ring next to the text, so it shows a tint dot instead.
private struct WidgetNutrientRow: View {
    let nutrient: NutrientSnapshot
    var compact = false

    var body: some View {
        let progress = nutrient.progress

        HStack(spacing: compact ? 8 : 10) {
            HStack(spacing: compact ? 8 : 10) {
                if !compact {
                    ProgressRing(fraction: progress.ringFraction,
                                 color: progress.status.ringColor(tint: nutrient.tint),
                                 trackColor: nutrient.tint.trackColor,
                                 lineWidth: 6,
                                 symbolName: nutrient.symbolName,
                                 symbolColor: nutrient.tint.color,
                                 showsCheck: nutrient.isMet,
                                 label: nutrient.name,
                                 valueDescription: progress.progressText)
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        if compact {
                            Image(systemName: nutrient.isMet ? "checkmark.circle.fill" : "circle.fill")
                                .font(.system(size: nutrient.isMet ? 10 : 7))
                                .foregroundStyle(nutrient.tint.color)
                        }
                        Text(nutrient.name)
                            .font((compact ? Font.subheadline : .body).weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    // Separate texts: fonts set inside an interpolated Text don't apply in widgets.
                    HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 4) {
                        Text(progress.currentText)
                            .font((compact ? Font.caption : .subheadline).weight(.bold)).fontDesign(.rounded)
                            .foregroundStyle(Theme.textPrimary)
                        Text(progress.goalText)
                            .font(compact ? .caption : .subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Ring, name and value as one stop ("Vitamin D, 2,000 of 4,000 IU, 2,000 IU to go"), then the "+".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(nutrient.name)
            .accessibilityValue("\(progress.progressText), \(progress.remainingText)")

            Button(intent: LogNutrientIntent(nutrientID: nutrient.id)) {
                Image(systemName: "plus")
                    .font((compact ? Font.footnote : .body).weight(.bold))
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(width: compact ? 34 : 44, height: compact ? 34 : 36)
                    .background(Theme.controlPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add one step of \(nutrient.name)")
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    NutrxMediumWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
    NutrxWidgetEntry.empty
}

#Preview("Small", as: .systemSmall) {
    NutrxMediumWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    NutrxMediumWidget()
} timeline: {
    NutrxWidgetEntry.placeholder
}
