import SwiftUI
import SwiftData

struct WatchTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WatchTodayViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sections) { section in
                    if viewModel.hasCustomGroups {
                        Text(section.name.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
                            .listRowBackground(Color.clear)
                    }

                    ForEach(section.intakes, id: \.nutrient.persistentModelID) { intake in
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
            }
            .listStyle(.carousel)
            .navigationTitle("Today")
            .onAppear {
                viewModel.refresh(context: modelContext)
            }
        }
    }
}
