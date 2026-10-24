import AppIntents
import SwiftData
import WidgetKit
import SwiftUI

@main
struct NutrxWidgetsBundle: WidgetBundle {
    init() {
        // The store for the nutrient and stack pickers (`NutrientEntityQuery`, `StackEntityQuery`) when a control or
        // widget is configured here: the extension-safe container, never `create()` (docs/pro/WIDGETS.md §2). Opened
        // only when a query first asks for it.
        AppDependencyManager.shared.add(dependency: Self.openStore())
    }

    /// The shared store read-only, or an empty one if it can't be opened, so a picker shows nothing rather than the
    /// extension crashing.
    /// Nonisolated: App Intents can resolve the dependency off the main actor.
    nonisolated private static func openStore() -> ModelContainer {
        if let container = try? ModelContainerFactory.createForExtension(allowsSave: false) { return container }
        let empty = ModelConfiguration(schema: ModelContainerFactory.schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: ModelContainerFactory.schema, configurations: [empty])
    }

    var body: some Widget {
        NutrxSmallWidget()
        NutrxMediumWidget()
        NutrxCircularWidget()
        NutrxRectangularWidget()
        NutrxInlineWidget()
        // nutrx Pro (#138): Control Center, Lock Screen and Action button controls.
        NutrxLogStackControl()
        NutrxLogNutrientControl()
    }
}
