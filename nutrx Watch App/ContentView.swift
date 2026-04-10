import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Query(filter: #Predicate<Nutrient> { !$0.isDeleted }) private var nutrients: [Nutrient]

    var body: some View {
        if nutrients.isEmpty {
            ContentUnavailableView(
                "No Nutrients",
                systemImage: "pill",
                description: Text("Open nutrx on your iPhone to add nutrients.")
            )
        } else {
            WatchTodayView()
        }
    }
}
