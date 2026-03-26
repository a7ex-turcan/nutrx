import SwiftUI
import SwiftData

struct MoveToGroupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]
    let nutrient: Nutrient

    @State private var showNewGroupPrompt = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(allGroups, id: \.persistentModelID) { group in
                    Button {
                        moveNutrient(to: group)
                    } label: {
                        HStack {
                            Text(group.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if nutrient.group?.persistentModelID == group.persistentModelID ||
                               (nutrient.group == nil && group.isSystem) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Button {
                    newGroupName = ""
                    showNewGroupPrompt = true
                } label: {
                    Label("New Group…", systemImage: "plus")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move to Group")
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
        let maxOrder = (group.nutrients ?? []).map(\.groupSortOrder).max() ?? -1
        nutrient.group = group
        nutrient.groupSortOrder = maxOrder + 1
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

        nutrient.group = group
        nutrient.groupSortOrder = 0
        dismiss()
    }
}
