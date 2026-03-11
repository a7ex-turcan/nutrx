import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                NavigationStack {
                    Text("Today")
                        .navigationTitle("Today")
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
                        .withProfileMenu()
                }
            }

            Tab("About", systemImage: "info.circle") {
                NavigationStack {
                    Text("About")
                        .navigationTitle("About")
                        .withProfileMenu()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
