import WidgetKit
import SwiftUI
import SwiftData

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let metCount: Int
    let totalCount: Int
    let currentStreak: Int
    let streaksEnabled: Bool
    /// False when the store couldn't be read. With no goals (or no data) the faces show a plain nutrx
    /// state, never a "0/0" that would look like a real score.
    var isAvailable = true

    var hasGoals: Bool { totalCount > 0 }
    var fraction: Double { totalCount > 0 ? Double(metCount) / Double(totalCount) : 0 }
    var score: String { WidgetSummary.score(met: metCount, total: totalCount) }
    var accessibilityLabel: String { hasGoals ? "\(metCount) of \(totalCount) goals met" : "nutrx" }

    static let placeholder = ComplicationEntry(date: .now, metCount: 3, totalCount: 6,
                                               currentStreak: 10, streaksEnabled: true)
    static let empty = ComplicationEntry(date: .now, metCount: 0, totalCount: 0,
                                         currentStreak: 0, streaksEnabled: true)
    static let unavailable = ComplicationEntry(date: .now, metCount: 0, totalCount: 0,
                                               currentStreak: 0, streaksEnabled: true, isAvailable: false)
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = makeEntry()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    @MainActor
    private func makeEntry() -> ComplicationEntry {
        // The extension-safe container: no CloudKit, none of `create()`'s one-off steps.
        // Fails e.g. while the store still needs a migration only the Watch app runs.
        guard let container = try? ModelContainerFactory.createForExtension(allowsSave: false) else {
            return .unavailable
        }
        let context = container.mainContext

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let nutrientDescriptor = FetchDescriptor<Nutrient>(
            predicate: #Predicate { !$0.isDeleted }
        )
        let nutrients = (try? context.fetch(nutrientDescriptor)) ?? []

        let exclusionDescriptor = FetchDescriptor<Exclusion>(
            predicate: #Predicate<Exclusion> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let exclusions = (try? context.fetch(exclusionDescriptor)) ?? []
        let excludedIDs = Set(exclusions.compactMap { $0.nutrient?.persistentModelID })

        let intakeDescriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let records = (try? context.fetch(intakeDescriptor)) ?? []

        var totalsByID: [PersistentIdentifier: Double] = [:]
        for record in records {
            if let id = record.nutrient?.persistentModelID {
                totalsByID[id, default: 0] += record.amount
            }
        }

        let active = nutrients.filter { !excludedIDs.contains($0.persistentModelID) }
        let metCount = active.filter { nutrient in
            GoalProgress(nutrient: nutrient, current: totalsByID[nutrient.persistentModelID] ?? 0).countsAsMet
        }.count

        let streaksEnabled = (try? context.fetch(FetchDescriptor<UserPreferences>()))?.first?.streaksEnabled ?? true
        let streak = streaksEnabled ? StreakService.compute(context: context).current : 0

        return ComplicationEntry(date: .now, metCount: metCount, totalCount: active.count,
                                 currentStreak: streak, streaksEnabled: streaksEnabled)
    }
}

// MARK: - Circular (segmented ring)

/// One segment per goal, met ones green, with "3/6" in the middle (DESIGN.md §5.11).
struct CircularComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        ZStack {
            SegmentedDayRing(met: entry.metCount, total: entry.totalCount, style: .onForest, showsLabel: false)
            if entry.hasGoals {
                Text(entry.score)
                    .font(.headline).fontDesign(.rounded)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
            } else {
                Image(systemName: "pills.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.greenSoft)
                    .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilityLabel)
    }
}

// MARK: - Corner (count + curved gauge)

struct CornerComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        if entry.hasGoals {
            Text(entry.score)
                .font(.title3.weight(.bold)).fontDesign(.rounded)
                .minimumScaleFactor(0.6)
                .widgetCurvesContent()
                .widgetLabel {
                    // A progress view fills the curve up to the share met; a gauge there only draws a marker.
                    ProgressView(value: entry.fraction) {
                        Text("Goals")
                    }
                    .tint(Theme.green)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.accessibilityLabel)
        } else {
            Image(systemName: "pills.fill")
                .font(.title3)
                .foregroundStyle(Theme.greenSoft)
                .widgetAccentable()
                .widgetLabel("nutrx")
                .accessibilityLabel(entry.accessibilityLabel)
        }
    }
}

// MARK: - Rectangular ("nutrx · 3/6" + segment bar)

struct RectangularComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.hasGoals ? "nutrx · \(entry.score)" : "nutrx")
                .font(.headline)
                .foregroundStyle(Theme.greenSoft)
                .widgetAccentable()

            if entry.hasGoals {
                Spacer(minLength: 0)
                SegmentBar(met: entry.metCount, total: entry.totalCount)
            } else if entry.isAvailable {
                Text(WidgetSummary.nextLine(firstUnmetName: nil, total: 0))
                    .font(.footnote)
                    .foregroundStyle(Theme.onForestSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilityLabel)
    }
}

/// A row of capsules, one per goal (scaled down past 12), met ones first in green.
private struct SegmentBar: View {
    let met: Int
    let total: Int

    var body: some View {
        let segments = WidgetSummary.segments(met: met, total: total)
        HStack(spacing: 3) {
            ForEach(0..<segments.count, id: \.self) { index in
                if index < segments.filled {
                    Capsule().fill(Theme.green).widgetAccentable()
                } else {
                    Capsule().fill(Theme.onForestTrack)
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Inline

struct InlineComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        Text(WidgetSummary.watchInline(met: entry.metCount, total: entry.totalCount,
                                       streakDays: entry.currentStreak, streaksEnabled: entry.streaksEnabled))
    }
}

// MARK: - Widget Configurations
// Kind IDs never change — complications people have placed would disappear.

struct NutrxCircularComplication: Widget {
    let kind = "NutrxCircularComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            CircularComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Goals")
        .description("Goals met today, one segment each.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct NutrxCornerComplication: Widget {
    let kind = "NutrxCornerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            CornerComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Goals gauge")
        .description("Goals met today, along the corner.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct NutrxRectangularComplication: Widget {
    let kind = "NutrxRectangularComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            RectangularComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Goals bar")
        .description("Goals met today, as a bar.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct NutrxInlineComplication: Widget {
    let kind = "NutrxInlineComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            InlineComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Goals and streak")
        .description("Goals met today and your streak.")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    NutrxCircularComplication()
} timeline: {
    ComplicationEntry.placeholder
    ComplicationEntry.unavailable
}

#Preview("Corner", as: .accessoryCorner) {
    NutrxCornerComplication()
} timeline: {
    ComplicationEntry.placeholder
    ComplicationEntry.unavailable
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NutrxRectangularComplication()
} timeline: {
    ComplicationEntry.placeholder
    ComplicationEntry.empty
}

#Preview("Inline", as: .accessoryInline) {
    NutrxInlineComplication()
} timeline: {
    ComplicationEntry.placeholder
}
