import AppIntents
import SwiftUI
import SwiftData
import WidgetKit

@main
struct nutrxApp: App {
    let modelContainer = ModelContainerFactory.create()
    /// nutrx Pro, from StoreKit. Created at launch so it hears `Transaction.updates` from the start.
    @State private var proAccess = ProAccess()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Siri and Shortcuts intents run in this process and use the app's store, not a second container.
        let container = modelContainer
        AppDependencyManager.shared.add(dependency: container)
        // Here too, not only on .active: Siri can launch the app in the background to log a stack.
        if StackLogging.repairDuplicateIDs(context: container.mainContext) {
            NutrxShortcuts.updateAppShortcutParameters()  // phrases registered with the old shared id
        }
        #if DEBUG
        if ScreenshotDemoData.isRequested {
            ScreenshotDemoData.replaceStore(in: modelContainer.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(proAccess)
                .task { await proAccess.refreshEntitlement() }
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
