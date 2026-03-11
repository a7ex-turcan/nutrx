import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TodayViewModel()

    var body: some View {
        ScrollView {
            if viewModel.nutrientIntakes.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.nutrientIntakes, id: \.nutrient.persistentModelID) { entry in
                        NutrientRowView(
                            nutrient: entry.nutrient,
                            currentIntake: entry.total,
                            onIncrement: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.increment(entry.nutrient, context: modelContext)
                                }
                            },
                            onDecrement: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.decrement(entry.nutrient, context: modelContext)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh(context: modelContext)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Nutrients", systemImage: "leaf")
        } description: {
            Text("Add nutrients in the My Nutrients tab to start tracking.")
        }
        .padding(.top, 60)
    }
}

#Preview {
    NavigationStack {
        TodayView()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(for: [Nutrient.self, IntakeRecord.self, Exclusion.self], inMemory: true)
}
