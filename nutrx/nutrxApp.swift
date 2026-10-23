import AppIntents
import SwiftUI
import UserNotifications
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
        // Refill reminder actions (Refilled, Remind me tomorrow) and taps; actions can arrive with the app in the
        // background.
        NotificationHandler.shared.container = container
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        NotificationHandler.registerCategories()
        #if DEBUG
        if ScreenshotDemoData.isRequested {
            ScreenshotDemoData.replaceStore(in: modelContainer.mainContext)
        }
        ScheduleDebug.apply(to: modelContainer.mainContext)  // until the Schedule sheet exists (#132)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The window's width class for large-screen layouts (#151); sheets inherit it.
                .measuresWidthClass()
                .environment(proAccess)
                .environment(NotificationRouter.shared)
                .task { await proAccess.refreshEntitlement() }
                .onChange(of: proAccess.isPro) {
                    // Becoming Pro (or lapsing) adds or removes refill reminders.
                    NotificationService.refreshAllNutrientReminders(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
        // Rolls the per-date dose-reminder window forward without the app being opened (#4).
        .backgroundTask(.appRefresh(NotificationService.reminderRefreshTaskID)) { [modelContainer, proAccess] in
            // Pro decides whether refill reminders stay, so check it before syncing.
            await proAccess.refreshEntitlement()
            await NotificationService.refreshRemindersInBackground(container: modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // A subscription that lapses sends no `Transaction.updates`, so look again whenever the app comes back.
                Task { await proAccess.refreshEntitlement() }
                StackLogging.repairDuplicateIDs(context: modelContainer.mainContext)
                WidgetCenter.shared.reloadAllTimelines()
                // Siri's "Log my <nutrient>" phrases use the current nutrient names.
                NutrxShortcuts.updateAppShortcutParameters()
            }
        }
    }
}
