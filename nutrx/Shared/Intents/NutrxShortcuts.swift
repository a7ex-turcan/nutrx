import AppIntents

/// nutrx's App Shortcuts: available in Siri, Spotlight and the Shortcuts app with no setup.
/// Every phrase has to name the app. The nutrient phrases use the user's own nutrient names, so they're refreshed
/// (`updateAppShortcutParameters()`) whenever the app becomes active.
struct NutrxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogNutrientShortcutIntent(),
            phrases: [
                "Log \(\.$nutrient) in \(.applicationName)",
                "Log my \(\.$nutrient) with \(.applicationName)",
                "Add \(\.$nutrient) in \(.applicationName)",
                "Log a nutrient in \(.applicationName)",
            ],
            shortTitle: "Log Nutrient",
            systemImageName: "plus.circle"
        )
    }
}
