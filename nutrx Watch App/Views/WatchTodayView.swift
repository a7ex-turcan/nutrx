import SwiftUI
import SwiftData

struct WatchTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WatchTodayViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.nutrientIntakes, id: \.nutrient.persistentModelID) { intake in
                    WatchNutrientRowView(
                        nutrient: intake.nutrient,
                        total: intake.total,
                        onIncrement: {
                            viewModel.increment(intake.nutrient, context: modelContext)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Today")
            .onAppear {
                viewModel.refresh(context: modelContext)
            }
        }
    }
}
