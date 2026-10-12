import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

            Tab("My Nutrients", systemImage: "leaf") {
                NutrientsListView()
            }

            Tab("History", systemImage: "chart.bar.xaxis") {
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
