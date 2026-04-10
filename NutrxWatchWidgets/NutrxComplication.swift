import WidgetKit
import SwiftUI
import SwiftData

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let onTarget: Int
    let total: Int
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, onTarget: 3, total: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = makeEntry()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    @MainActor
    private func makeEntry() -> ComplicationEntry {
        let container = ModelContainerFactory.create()
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
        var onTarget = 0
        for nutrient in active {
            let total = max(0, totalsByID[nutrient.persistentModelID] ?? 0)
            let hit: Bool
            switch nutrient.goalType {
            case .minimum:
                hit = total >= nutrient.dailyTarget
            case .maximum:
                hit = total <= nutrient.dailyTarget
            case .range:
                if let upper = nutrient.upperBound {
                    hit = total >= nutrient.dailyTarget && total <= upper
                } else {
                    hit = total >= nutrient.dailyTarget
                }
            }
            if hit { onTarget += 1 }
        }

        return ComplicationEntry(date: .now, onTarget: onTarget, total: active.count)
    }
}

// MARK: - Circular Complication (Ring Gauge)

struct CircularComplicationView: View {
    let entry: ComplicationEntry

    private var progress: Double {
        guard entry.total > 0 else { return 0 }
        return Double(entry.onTarget) / Double(entry.total)
    }

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "pill.fill")
        } currentValueLabel: {
            Text("\(entry.onTarget)")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.blue)
    }
}

// MARK: - Corner Complication (Count)

struct CornerComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        Text("\(entry.onTarget)/\(entry.total)")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .widgetLabel {
                Text("on target")
            }
    }
}

// MARK: - Inline Complication (Text)

struct InlineComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        Text("\(entry.onTarget) / \(entry.total) on target")
    }
}

// MARK: - Widget Configurations

struct NutrxCircularComplication: Widget {
    let kind = "NutrxCircularComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            CircularComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("nutrx Progress")
        .description("Shows how many nutrients are on target today.")
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
        .configurationDisplayName("nutrx Count")
        .description("Shows nutrient count on target today.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct NutrxInlineComplication: Widget {
    let kind = "NutrxInlineComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            InlineComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("nutrx Inline")
        .description("Shows nutrients on target as inline text.")
        .supportedFamilies([.accessoryInline])
    }
}
