import WidgetKit

/// Reads Pro from StoreKit and the running nutrients from the shared store (read-only); refreshes at midnight and on
/// `WidgetReload` (a log changes what's left in a bottle).
struct SupplyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SupplyWidgetEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (SupplyWidgetEntry) -> Void) {
        guard !context.isPreview else { return completion(.sample) }
        Task { completion(await entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SupplyWidgetEntry>) -> Void) {
        Task {
            let entry = await entry()
            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    private func entry() async -> SupplyWidgetEntry {
        guard await ProEntitlement.current() != nil else { return .freeSample }
        let summary = await MainActor.run {
            ExtensionStore.read { context in
                SupplyWidgetSummary.make(ExtensionStore.todaysNutrients(in: context))
            }
        }
        return SupplyWidgetEntry(date: .now, content: summary.map { .summary($0) } ?? .unavailable)
    }
}
