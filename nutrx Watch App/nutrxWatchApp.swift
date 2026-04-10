import SwiftUI
import SwiftData
import WidgetKit

@main
struct nutrxWatchApp: App {
    let modelContainer = ModelContainerFactory.create()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
