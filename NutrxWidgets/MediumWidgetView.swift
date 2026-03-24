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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct MediumWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: NutrxWidgetEntry

    var body: some View {
        if entry.totalCount == 0 {
            Text("Open nutrx to add nutrients")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .widgetURL(URL(string: "nutrx://nutrients"))
        } else {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemLarge:
                largeLayout
            default:
                mediumLayout
            }
        }
    }

    // MARK: - Small Layout (2 nutrients, compact)

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text("\(entry.completedCount)/\(entry.totalCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(entry.nutrients.prefix(2).enumerated()), id: \.offset) { _, nutrient in
                CompactNutrientRow(nutrient: nutrient)
            }

            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "nutrx://today"))
    }

    // MARK: - Large Layout (up to 6 nutrients)

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            ForEach(Array(entry.nutrients.prefix(6).enumerated()), id: \.offset) { _, nutrient in
                NutrientWidgetRow(nutrient: nutrient)
            }

            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "nutrx://today"))
    }

    // MARK: - Medium Layout (3 nutrients, full)

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            ForEach(Array(entry.nutrients.prefix(3).enumerated()), id: \.offset) { _, nutrient in
                NutrientWidgetRow(nutrient: nutrient)
            }
        }
        .widgetURL(URL(string: "nutrx://today"))
    }
}

// MARK: - Compact Row (Small Widget)

private struct CompactNutrientRow: View {
    let nutrient: NutrientSnapshot

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(nutrient.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Button(intent: LogNutrientIntent(nutrientID: nutrient.id)) {
                    Image(systemName: nutrient.isOnTarget ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(nutrient.isOnTarget ? .green : .blue)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: min(geo.size.width, geo.size.width * nutrient.progress))
                }
            }
            .frame(height: 4)
        }
    }

    private var barColor: Color {
        if nutrient.isExceeded { return .orange }
        if nutrient.isOnTarget { return .green }
        return .blue
    }
}

// MARK: - Full Row (Medium Widget)

private struct NutrientWidgetRow: View {
    let nutrient: NutrientSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text(nutrient.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)

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

            Text("\(nutrient.current.displayString)/\(nutrient.target.displayString)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(nutrient.isExceeded ? .orange : .secondary)
                .lineLimit(1)
                .frame(width: 60, alignment: .trailing)

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
