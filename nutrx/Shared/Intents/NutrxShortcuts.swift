import AppIntents

/// nutrx's App Shortcuts: available in Siri, Spotlight and the Shortcuts app with no setup.
/// Every phrase has to name the app. The nutrient and stack phrases use the user's own names, so they're refreshed
/// (`updateAppShortcutParameters()`) whenever the app becomes active and after stacks change.
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
        // The first phrase is the one the Siri tip on a stack's detail screen shows (`StackShortcutLogging.siriPhrase`);
        // the second is the tip's for a name that already ends in "stack" ("Log the Morning stack with nutrx", #292).
        // Never "Log my <stack> with nutrx": that's the nutrient phrase, and a stack named like a nutrient would clash.
        AppShortcut(
            intent: LogStackShortcutIntent(),
            phrases: [
                "Log my \(\.$stack) stack with \(.applicationName)",
                "Log the \(\.$stack) with \(.applicationName)",
                "Log my \(\.$stack) stack in \(.applicationName)",
                "Log the \(\.$stack) stack in \(.applicationName)",
                "Log a stack in \(.applicationName)",
            ],
            shortTitle: "Log Stack",
            systemImageName: "square.stack.3d.up"
        )
    }
}
