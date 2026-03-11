import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                Text("Today")
            }

            Tab("My Nutrients", systemImage: "leaf") {
                Text("My Nutrients")
            }

            Tab("History", systemImage: "chart.bar.xaxis") {
                Text("History")
            }

            Tab("Profile", systemImage: "person.crop.circle") {
                Text("Profile")
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
