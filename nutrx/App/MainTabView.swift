import SwiftUI
import SwiftData

struct MainTabView: View {
    enum TabID: Hashable { case today, nutrients, history }

    @State private var selection: TabID = .today
    @Environment(NotificationRouter.self) private var router: NotificationRouter?

    var body: some View {
        TabView(selection: $selection) {
            // Icons and labels from the design (Main.dc.html): rings for Today, a leaf for Nutrients, a calendar
            // for History. The Nutrients screen keeps its "My Nutrients" title.
            Tab("Today", systemImage: "circle.circle", value: TabID.today) {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

            Tab("Nutrients", systemImage: "leaf", value: TabID.nutrients) {
                NutrientsListView()
            }

            Tab("History", systemImage: "calendar", value: TabID.history) {
                NavigationStack {
                    HistoryListView()
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

        }
        // A refill reminder opens that nutrient's analytics (My Nutrients pushes it).
        .onChange(of: router?.supplyNutrientID) { _, id in
            if id != nil { selection = .nutrients }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
