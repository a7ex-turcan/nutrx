import SwiftUI

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
                    Text("History")
                        .navigationTitle("History")
                        .navigationBarTitleDisplayMode(.inline)
                        .withProfileMenu()
                }
            }

            Tab("About", systemImage: "info.circle") {
                NavigationStack {
                    Text("About")
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
}
