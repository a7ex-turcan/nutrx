import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            // Icons and labels from the design (Main.dc.html): rings for Today, a leaf for Nutrients, a calendar
            // for History. The Nutrients screen keeps its "My Nutrients" title.
            Tab("Today", systemImage: "circle.circle") {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

            Tab("Nutrients", systemImage: "leaf") {
                NutrientsListView()
            }

            Tab("History", systemImage: "calendar") {
                NavigationStack {
                    HistoryListView()
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
