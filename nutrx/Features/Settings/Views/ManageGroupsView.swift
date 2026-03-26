import SwiftUI
import SwiftData

struct ManageGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]

    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var groupToRename: NutrientGroup?
    @State private var renameText = ""
    @State private var groupToDelete: NutrientGroup?

    private var nonSystemGroups: [NutrientGroup] {
        allGroups.filter { !$0.isSystem }
    }

    private var systemGroup: NutrientGroup? {
        allGroups.first(where: { $0.isSystem })
    }

    var body: some View {
        List {
            if !nonSystemGroups.isEmpty {
                Section {
                    ForEach(nonSystemGroups, id: \.persistentModelID) { group in
                        HStack {
                            Text(group.name)
                                .font(.body)

                            Spacer()

                            Text("\((group.nutrients ?? []).count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            renameText = group.name
                            groupToRename = group
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                groupToDelete = group
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveGroups)
                } header: {
                    Text("Custom Groups")
                } footer: {
                    Text("Tap to rename. Drag to reorder. Swipe to delete.")
                }
            }

            if let general = systemGroup {
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(general.name)
                            .font(.body)

                        Spacer()

                        Text("\((general.nutrients ?? []).count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("System")
                } footer: {
                    Text("Nutrients without a group are placed here. This group cannot be renamed or deleted.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newGroupName = ""
                    showNewGroupAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Create") { createGroup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new group.")
        }
        .alert("Rename Group", isPresented: Binding(
            get: { groupToRename != nil },
            set: { if !$0 { groupToRename = nil } }
        )) {
            TextField("Group name", text: $renameText)
            Button("Save") {
                if let group = groupToRename {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        group.name = trimmed
                    }
                    groupToRename = nil
                }
            }
            Button("Cancel", role: .cancel) { groupToRename = nil }
        } message: {
            Text("Enter a new name for this group.")
        }
        .alert(
            "Delete \(groupToDelete?.name ?? "Group")?",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                }
                groupToDelete = nil
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: {
            let count = (groupToDelete?.nutrients ?? []).count
            Text("\(groupToDelete?.name ?? "This group") will be deleted. Its \(count) nutrient\(count == 1 ? "" : "s") will move to General.")
        }
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newOrder = (nonSystemGroups.map(\.sortOrder).max() ?? -1) + 1
        let group = NutrientGroup(name: trimmed, sortOrder: newOrder)
        modelContext.insert(group)
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = nonSystemGroups.sorted { $0.sortOrder < $1.sortOrder }
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.sortOrder = index
        }
    }

    private func deleteGroup(_ group: NutrientGroup) {
        guard let general = systemGroup else { return }
        let maxOrder = (general.nutrients ?? []).map(\.groupSortOrder).max() ?? -1
        for (offset, nutrient) in (group.nutrients ?? []).enumerated() {
            nutrient.group = general
            nutrient.groupSortOrder = maxOrder + 1 + offset
        }
        modelContext.delete(group)
    }
}

#Preview {
    NavigationStack {
        ManageGroupsView()
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
