import SwiftUI
import SwiftData

struct NutrientsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Nutrient> { !$0.isDeleted },
           sort: \Nutrient.sortOrder)
    private var nutrients: [Nutrient]
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]

    @State private var showAddSheet = false
    @State private var addDraft = NutrientDraft()
    @State private var editDraft = NutrientDraft()
    @State private var selectedGroupForAdd: NutrientGroup?
    @State private var nutrientToEdit: Nutrient?
    @State private var nutrientToDelete: Nutrient?
    @State private var nutrientToMove: Nutrient?
    @Query private var allPreferences: [UserPreferences]

    private var generalGroup: NutrientGroup? {
        allGroups.first(where: { $0.isSystem })
    }

    private var hasCustomGroups: Bool {
        allGroups.contains(where: { !$0.isSystem })
    }

    private var groupedSections: [(group: NutrientGroup, nutrients: [Nutrient])] {
        var sectionMap: [PersistentIdentifier: [Nutrient]] = [:]
        for nutrient in nutrients {
            let groupID = (nutrient.group ?? generalGroup)?.persistentModelID ?? generalGroup?.persistentModelID
            guard let gid = groupID else { continue }
            sectionMap[gid, default: []].append(nutrient)
        }

        // Sort nutrients within each group by groupSortOrder, then sortOrder as tiebreaker
        for key in sectionMap.keys {
            sectionMap[key]?.sort {
                if $0.groupSortOrder != $1.groupSortOrder {
                    return $0.groupSortOrder < $1.groupSortOrder
                }
                return $0.sortOrder < $1.sortOrder
            }
        }

        return allGroups.compactMap { group in
            guard let nutrients = sectionMap[group.persistentModelID], !nutrients.isEmpty else { return nil }
            return (group: group, nutrients: nutrients)
        }
    }

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
            .navigationBarTitleDisplayMode(.inline)
            .withProfileMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addDraft.reset()
                        selectedGroupForAdd = generalGroup
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let nutrient = nutrients.first(where: { $0.persistentModelID == id }) {
                    NutrientAnalyticsView(nutrient: nutrient)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NutrientFormView(
                    draft: addDraft,
                    title: "New Nutrient",
                    buttonLabel: "Add Nutrient",
                    selectedGroup: $selectedGroupForAdd,
                    showGroupPicker: true
                ) {
                    addNutrient()
                }
            }
            .sheet(item: $nutrientToEdit) { nutrient in
                NutrientFormView(
                    draft: editDraft,
                    title: "Edit Nutrient",
                    buttonLabel: "Save Changes",
                    nutrient: nutrient,
                    onDelete: {
                        nutrientToEdit = nil
                        nutrientToDelete = nutrient
                    }
                ) {
                    applyEdit(to: nutrient)
                }
            }
            .sheet(item: $nutrientToMove) { nutrient in
                MoveToGroupSheet(nutrient: nutrient)
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
            if let prefs = allPreferences.first, !prefs.hasSeenAnalyticsBanner {
                analyticsBanner
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(groupedSections, id: \.group.persistentModelID) { section in
                Section {
                    if !section.group.isCollapsed {
                        ForEach(section.nutrients, id: \.persistentModelID) { nutrient in
                            NavigationLink(value: nutrient.persistentModelID) {
                                nutrientRow(nutrient)
                            }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        nutrientToDelete = nutrient
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        editDraft.populate(from: nutrient)
                                        nutrientToEdit = nutrient
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button {
                                        editDraft.populate(from: nutrient)
                                        nutrientToEdit = nutrient
                                    } label: {
                                        Label("Edit Nutrient", systemImage: "pencil")
                                    }

                                    Button {
                                        nutrientToMove = nutrient
                                    } label: {
                                        Label("Move to Group", systemImage: "folder")
                                    }

                                    Button(role: .destructive) {
                                        nutrientToDelete = nutrient
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove { source, destination in
                            moveNutrients(in: section.group, from: source, to: destination)
                        }
                    }
                } header: {
                    if hasCustomGroups {
                        GroupHeaderView(
                            name: section.group.name,
                            isCollapsed: section.group.isCollapsed,
                            intakes: [], // No aggregate progress needed in My Nutrients
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    section.group.isCollapsed.toggle()
                                }
                            }
                        )
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(nutrient.name)
                        .font(.body.weight(.medium))

                    if let notes = nutrient.notes, !notes.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.caption2)
                        switch nutrient.goalType {
                        case .range:
                            Text("\(nutrient.dailyTarget.displayString)–\((nutrient.upperBound ?? nutrient.dailyTarget).displayString) \(nutrient.unit)/day")
                        case .minimum, .maximum:
                            Text("\(nutrient.dailyTarget.displayString) \(nutrient.unit)/day")
                        }
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                        let count = nutrient.reminders?.count ?? 0
                        Text("\(count) Reminder\(count == 1 ? "" : "s")")
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.caption2)
                        Text("\(nutrient.step.displayString)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

        }
    }

    // MARK: - Analytics Banner

    private var analyticsBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tap a nutrient to see your stats")
                    .font(.subheadline.weight(.medium))
                Text("Swipe or long-press to edit, move, or delete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    allPreferences.first?.hasSeenAnalyticsBanner = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func addNutrient() {
        guard let stepValue = addDraft.step.parsedDouble,
              let targetValue = addDraft.dailyTarget.parsedDouble else { return }

        let nutrient = Nutrient(
            name: addDraft.name.trimmingCharacters(in: .whitespaces),
            unit: addDraft.unit.trimmingCharacters(in: .whitespaces),
            step: stepValue,
            dailyTarget: targetValue,
            sortOrder: nutrients.count,
            goalType: addDraft.goalType,
            upperBound: addDraft.goalType == .range ? addDraft.upperBound.parsedDouble : nil
        )
        let notes = addDraft.notes.trimmingCharacters(in: .whitespaces)
        nutrient.notes = notes.isEmpty ? nil : notes

        let targetGroup = selectedGroupForAdd ?? generalGroup
        if let group = targetGroup {
            nutrient.group = group
            nutrient.groupSortOrder = ((group.nutrients ?? []).map(\.groupSortOrder).max() ?? -1) + 1
        }

        modelContext.insert(nutrient)

        for time in addDraft.pendingReminderTimes {
            let reminder = NutrientReminder(nutrient: nutrient, timeOfDay: time)
            modelContext.insert(reminder)
        }
        if !addDraft.pendingReminderTimes.isEmpty {
            NotificationService.scheduleReminders(for: nutrient)
        }
    }

    private func applyEdit(to nutrient: Nutrient) {
        guard let stepValue = editDraft.step.parsedDouble,
              let targetValue = editDraft.dailyTarget.parsedDouble else { return }

        nutrient.name = editDraft.name.trimmingCharacters(in: .whitespaces)
        nutrient.unit = editDraft.unit.trimmingCharacters(in: .whitespaces)
        nutrient.step = stepValue
        nutrient.dailyTarget = targetValue
        nutrient.goalType = editDraft.goalType
        nutrient.upperBound = editDraft.goalType == .range ? editDraft.upperBound.parsedDouble : nil
        let notes = editDraft.notes.trimmingCharacters(in: .whitespaces)
        nutrient.notes = notes.isEmpty ? nil : notes
    }

    private func moveNutrients(in group: NutrientGroup, from source: IndexSet, to destination: Int) {
        var groupNutrients = nutrients
            .filter { ($0.group ?? generalGroup)?.persistentModelID == group.persistentModelID }
            .sorted { $0.groupSortOrder < $1.groupSortOrder }
        groupNutrients.move(fromOffsets: source, toOffset: destination)
        for (index, nutrient) in groupNutrients.enumerated() {
            nutrient.groupSortOrder = index
        }
    }

}

#Preview {
    NutrientsListView()
        .modelContainer(previewContainer)
}
