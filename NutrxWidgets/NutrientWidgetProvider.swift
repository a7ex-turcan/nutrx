import AppIntents
import WidgetKit

/// Reads the chosen nutrient and today's total from the shared store, and Pro from StoreKit; refreshes at midnight
/// and after a log (`WidgetReload`).
struct NutrientWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NutrientWidgetEntry {
        .sample
    }

    func snapshot(for configuration: NutrientWidgetConfiguration, in context: Context) async -> NutrientWidgetEntry {
        context.isPreview ? .sample : await entry(for: configuration)
    }

    func timeline(for configuration: NutrientWidgetConfiguration,
                  in context: Context) async -> Timeline<NutrientWidgetEntry> {
        let entry = await entry(for: configuration)
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
        return Timeline(entries: [entry], policy: .after(midnight))
    }

    private func entry(for configuration: NutrientWidgetConfiguration) async -> NutrientWidgetEntry {
        // Pro is asked of StoreKit here, as the other widgets do; nothing is cached from the app.
        let isPro = await ProEntitlement.current() != nil
        let chosen = configuration.nutrient
        return await MainActor.run {
            let nutrient = chosen.flatMap { ExtensionStore.nutrient(id: $0.id) }
            let content = NutrientWidgetContent.make(
                chosen: chosen != nil, nutrient: nutrient,
                todayTotal: nutrient.map { ExtensionStore.todayTotal(of: $0) } ?? 0, isPro: isPro)
            return NutrientWidgetEntry(date: .now, content: content)
        }
    }
}
