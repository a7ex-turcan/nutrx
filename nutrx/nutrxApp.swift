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
        // Here too, not only on .active: Siri can launch the app in the background to log a stack.
        StackLogging.repairDuplicateIDs(context: container.mainContext)
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
                StackLogging.repairDuplicateIDs(context: modelContainer.mainContext)
                WidgetCenter.shared.reloadAllTimelines()
                // Siri's "Log my <nutrient>" phrases use the current nutrient names.
                NutrxShortcuts.updateAppShortcutParameters()
            }
        }
    }
}
