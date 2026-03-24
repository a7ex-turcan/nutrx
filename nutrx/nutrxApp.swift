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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
