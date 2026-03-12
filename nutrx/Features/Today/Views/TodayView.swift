import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TodayViewModel()
    @State private var nutrientForCustomAmount: Nutrient?
    @State private var nutrientToEdit: Nutrient?
    @State private var editDraft = NutrientDraft()

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
                        .contextMenu {
                            Button {
                                nutrientForCustomAmount = entry.nutrient
                            } label: {
                                Label("Add Exact Amount", systemImage: "number")
                            }

                            Button {
                                editDraft.populate(from: entry.nutrient)
                                nutrientToEdit = entry.nutrient
                            } label: {
                                Label("Edit Nutrient", systemImage: "pencil")
                            }
                        }
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
        .sheet(item: $nutrientForCustomAmount) { nutrient in
            CustomAmountSheet(nutrient: nutrient) { amount in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.addCustomAmount(amount, to: nutrient, context: modelContext)
                }
            }
        }
        .sheet(item: $nutrientToEdit) { nutrient in
            NutrientFormView(
                draft: editDraft,
                title: "Edit Nutrient",
                buttonLabel: "Save Changes"
            ) {
                applyEdit(to: nutrient)
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

    private func applyEdit(to nutrient: Nutrient) {
        guard let stepValue = Double(editDraft.step),
              let targetValue = Double(editDraft.dailyTarget) else { return }

        nutrient.name = editDraft.name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = editDraft.unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
        viewModel.refresh(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        TodayView()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
