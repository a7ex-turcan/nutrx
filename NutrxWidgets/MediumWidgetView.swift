import WidgetKit
import SwiftUI
import AppIntents

struct NutrxMediumWidget: Widget {
    let kind = "NutrxMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("nutrx — Today")
        .description("Track your top nutrients with quick-log buttons.")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: NutrxWidgetEntry

    var body: some View {
        if entry.totalCount == 0 {
            Text("Open nutrx to add nutrients")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .widgetURL(URL(string: "nutrx://nutrients"))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text("Today")
                        .font(.headline)

                    Spacer()

                    Text("\(entry.completedCount) / \(entry.totalCount)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray5), in: Capsule())
                }

                // Nutrient rows (top 3)
                ForEach(Array(entry.nutrients.prefix(3).enumerated()), id: \.offset) { _, nutrient in
                    NutrientWidgetRow(nutrient: nutrient)
                }
            }
            .widgetURL(URL(string: "nutrx://today"))
        }
    }
}

private struct NutrientWidgetRow: View {
    let nutrient: NutrientSnapshot

    var body: some View {
        HStack(spacing: 8) {
            // Name
            Text(nutrient.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: min(geo.size.width, geo.size.width * nutrient.progress))
                }
            }
            .frame(height: 6)

            // Value
            Text("\(nutrient.current.displayString)/\(nutrient.target.displayString)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(nutrient.isExceeded ? .orange : .secondary)
                .lineLimit(1)
                .frame(width: 60, alignment: .trailing)

            // + button
            Button(intent: LogNutrientIntent(nutrientID: nutrient.id)) {
                Image(systemName: nutrient.isOnTarget ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(nutrient.isOnTarget ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var barColor: Color {
        if nutrient.isExceeded { return .orange }
        if nutrient.isOnTarget { return .green }
        return .blue
    }
}
