import AppIntents
import SwiftUI
import SwiftData
import WidgetKit

@main
struct nutrxApp: App {
    let modelContainer = ModelContainerFactory.create()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Siri and Shortcuts intents run in this process and use the app's store, not a second container.
        let container = modelContainer
        AppDependencyManager.shared.add(dependency: container)
        #if DEBUG
        if ScreenshotDemoData.isRequested {
            ScreenshotDemoData.replaceStore(in: modelContainer.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        // Rolls the per-date dose-reminder window forward without the app being opened (#4).
        .backgroundTask(.appRefresh(NotificationService.reminderRefreshTaskID)) { [modelContainer] in
            await NotificationService.refreshRemindersInBackground(container: modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
                // Siri's "Log my <nutrient>" phrases use the current nutrient names.
                NutrxShortcuts.updateAppShortcutParameters()
            }
        }
    }
}
