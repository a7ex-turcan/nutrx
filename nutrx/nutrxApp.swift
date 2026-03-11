import SwiftUI
import SwiftData

@main
struct nutrxApp: App {
    let modelContainer = ModelContainerFactory.create()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
