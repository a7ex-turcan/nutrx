import SwiftUI
import SwiftData

struct NutrientsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Nutrient> { !$0.isDeleted },
           sort: \Nutrient.sortOrder)
    private var nutrients: [Nutrient]

    @State private var showAddSheet = false
    @State private var addDraft = NutrientDraft()
    @State private var editDraft = NutrientDraft()
    @State private var nutrientToEdit: Nutrient?
    @State private var nutrientToDelete: Nutrient?

    var body: some View {
        NavigationStack {
            Group {
                if nutrients.isEmpty {
                    emptyState
                } else {
                    nutrientList
                }
            }
            .navigationTitle("My Nutrients")
            .withProfileMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addDraft.reset()
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NutrientFormView(
                    draft: addDraft,
                    title: "New Nutrient",
                    buttonLabel: "Add Nutrient"
                ) {
                    addNutrient()
                }
            }
            .sheet(item: $nutrientToEdit) { nutrient in
                NutrientFormView(
                    draft: editDraft,
                    title: "Edit Nutrient",
                    buttonLabel: "Save Changes",
                    onDelete: {
                        nutrientToEdit = nil
                        nutrientToDelete = nutrient
                    }
                ) {
                    applyEdit(to: nutrient)
                }
            }
            .alert(
                "Delete \(nutrientToDelete?.name ?? "Nutrient")?",
                isPresented: Binding(
                    get: { nutrientToDelete != nil },
                    set: { if !$0 { nutrientToDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let nutrient = nutrientToDelete {
                        nutrient.isDeleted = true
                        nutrientToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    nutrientToDelete = nil
                }
            } message: {
                Text("This nutrient will be removed from your daily tracking. Your previously tracked intakes will not be affected.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Nutrients", systemImage: "leaf")
        } description: {
            Text("Tap + to add your first nutrient.")
        }
    }

    // MARK: - List

    private var nutrientList: some View {
        List {
            ForEach(nutrients) { nutrient in
                nutrientRow(nutrient)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editDraft.populate(from: nutrient)
                        nutrientToEdit = nutrient
                    }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    nutrientToDelete = nutrients[index]
                }
            }
            .onMove(perform: moveNutrients)
        }
        .listStyle(.insetGrouped)
    }

    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.name)
                    .font(.body.weight(.medium))

                Text("\(formatted(nutrient.dailyTarget)) \(nutrient.unit)/day  ·  step \(formatted(nutrient.step))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func addNutrient() {
        guard let stepValue = Double(addDraft.step),
              let targetValue = Double(addDraft.dailyTarget) else { return }

        let nutrient = Nutrient(
            name: addDraft.name.trimmingCharacters(in: .whitespaces),
            unit: addDraft.unit.trimmingCharacters(in: .whitespaces),
            step: stepValue,
            dailyTarget: targetValue,
            sortOrder: nutrients.count
        )
        modelContext.insert(nutrient)
    }

    private func applyEdit(to nutrient: Nutrient) {
        guard let stepValue = Double(editDraft.step),
              let targetValue = Double(editDraft.dailyTarget) else { return }

        nutrient.name = editDraft.name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = editDraft.unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
    }

    private func moveNutrients(from source: IndexSet, to destination: Int) {
        var reordered = nutrients
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, nutrient) in reordered.enumerated() {
            nutrient.sortOrder = index
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
    }
}

#Preview {
    NutrientsListView()
        .modelContainer(for: [Nutrient.self, IntakeRecord.self, Exclusion.self], inMemory: true)
}
