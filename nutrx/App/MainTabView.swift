import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                Text("Today")
            }

            Tab("My Nutrients", systemImage: "leaf") {
                NutrientsListView()
            }

            Tab("History", systemImage: "chart.bar.xaxis") {
                Text("History")
            }

            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }

            Tab("About", systemImage: "info.circle") {
                Text("About")
            }
        }
    }
}

#Preview {
    MainTabView()
}
