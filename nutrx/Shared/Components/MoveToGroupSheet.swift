import SwiftUI
import SwiftData

/// Picks a group (or a new one) for one nutrient, or several selected in My Nutrients (#98).
struct MoveToGroupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]
    let nutrients: [Nutrient]
    /// After the move, before the sheet closes (My Nutrients ends its selection).
    var onMoved: () -> Void = {}

    init(nutrient: Nutrient) {
        self.nutrients = [nutrient]
    }

    init(nutrients: [Nutrient], onMoved: @escaping () -> Void = {}) {
        self.nutrients = nutrients
        self.onMoved = onMoved
    }

    @State private var showNewGroupPrompt = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(allGroups, id: \.persistentModelID) { group in
                    // Checked when every nutrient being moved is already in it.
                    let isCurrent = nutrients.allSatisfy { nutrient in
                        nutrient.group?.persistentModelID == group.persistentModelID ||
                            (nutrient.group == nil && group.isSystem)
                    }
                    Button {
                        moveNutrient(to: group)
                    } label: {
                        HStack {
                            Text(group.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.controlPrimary)
                                    .accessibilityHidden(true)  // .isSelected says it; VoiceOver reads ✓ as "Selected"
                            }
                        }
                    }
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }

                Button {
                    newGroupName = ""
                    showNewGroupPrompt = true
                } label: {
                    Label("New Group…", systemImage: "plus")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(nutrients.count == 1 ? "Move to Group" : "Move \(nutrients.count) Nutrients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Group", isPresented: $showNewGroupPrompt) {
                TextField("Group name", text: $newGroupName)
                Button("Create") {
                    createGroupAndMove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new group.")
            }
        }
        .presentationDetents([.medium])
    }

    private func moveNutrient(to group: NutrientGroup) {
        group.append(nutrients)
        try? modelContext.save()
        onMoved()
        dismiss()
    }

    private func createGroupAndMove() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Insert before General (which has Int.max sortOrder)
        let nonSystemGroups = allGroups.filter { !$0.isSystem }
        let newOrder = (nonSystemGroups.map(\.sortOrder).max() ?? -1) + 1

        let group = NutrientGroup(name: trimmed, sortOrder: newOrder)
        modelContext.insert(group)

        group.append(nutrients)
        try? modelContext.save()
        onMoved()
        dismiss()
    }
}
