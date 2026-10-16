import SwiftUI
import SwiftData

struct MainTabView: View {
    enum TabID: Hashable { case today, nutrients, stacks, history }

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

            // Stacks have their own tab: something you build, like nutrients, and used daily from Today.
            Tab("Stacks", systemImage: "square.stack.3d.up", value: TabID.stacks) {
                NavigationStack {
                    // The profile menu is added inside, so + sits before the avatar.
                    StacksView()
                }
            }

            Tab("History", systemImage: "calendar", value: TabID.history) {
                NavigationStack {
                    // The profile menu is added inside, so the report button sits before the avatar.
                    HistoryListView()
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.large)
                }
            }

        }
        // A refill reminder opens that nutrient's analytics (My Nutrients pushes it).
        .onChange(of: router?.supplyNutrientID) { _, id in
            if id != nil { selection = .nutrients }
        }
        // Today's stacks row "Edit" opens the Stacks tab.
        .onChange(of: router?.showsStacks) { _, shows in
            if shows == true {
                selection = .stacks
                router?.showsStacks = false
            }
        }
        // A recap notification opens the recap (History pushes it).
        .onChange(of: router?.showsRecap) { _, shows in
            if shows == true { selection = .history }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
