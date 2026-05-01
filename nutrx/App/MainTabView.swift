import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                NavigationStack {
                    TodayView()
                        .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .navigationBarTitleDisplayMode(.inline)
                        .withProfileMenu()
                }
            }

            Tab("My Nutrients", systemImage: "leaf") {
                NutrientsListView()
            }

            Tab("History", systemImage: "chart.bar.xaxis") {
                NavigationStack {1
                    HistoryListView()
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.inline)
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
