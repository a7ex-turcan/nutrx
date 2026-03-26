import WidgetKit
import SwiftUI

struct NutrxSmallWidget: Widget {
    let kind = "NutrxSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutrxTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("nutrx")
        .description("Daily nutrient completion at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallWidgetView: View {
    let entry: NutrxWidgetEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.completedCount) / Double(entry.totalCount)
    }

    private var allComplete: Bool {
        entry.totalCount > 0 && entry.completedCount == entry.totalCount
    }

    private var ringColor: Color {
        allComplete ? .green : .blue
    }

    var body: some View {
        if entry.totalCount == 0 {
            // Empty state
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Add nutrients")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .widgetURL(URL(string: "nutrx://nutrients"))
        } else {
            VStack(spacing: 8) {
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)

                    // Fill
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)

                    // Count
                    Text("\(entry.completedCount)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(allComplete ? .green : .primary)
                }
                .frame(width: 70, height: 70)

                Text("of \(entry.totalCount) on target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if entry.streaksEnabled && entry.currentStreak >= 1 {
                    Text("🔥 \(entry.currentStreak)")
                        .font(.caption2.weight(.medium))
                }
            }
            .widgetURL(URL(string: "nutrx://today"))
        }
    }
}
