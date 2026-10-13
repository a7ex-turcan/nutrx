import SwiftUI
import SwiftData
import WidgetKit

@main
struct nutrxApp: App {
    let modelContainer = ModelContainerFactory.create()
    @Environment(\.scenePhase) private var scenePhase

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
            }
        }
    }
}
