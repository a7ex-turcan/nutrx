import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationBarTitleDisplayMode(.inline)
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
                        .navigationBarTitleDisplayMode(.inline)
                        .withProfileMenu()
                }
            }

            Tab("About", systemImage: "info.circle") {
                NavigationStack {
                    AboutView()
                        .navigationTitle("About")
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
