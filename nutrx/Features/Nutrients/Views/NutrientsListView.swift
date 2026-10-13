import SwiftUI
import SwiftData

struct NutrientsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
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
            .background(Theme.surfaceGround)
            .navigationTitle("My Nutrients")
            .navigationBarTitleDisplayMode(.large)
            .withProfileMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startAdding) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.controlOnPrimary)
                            .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                            .background(Theme.controlPrimary, in: Circle())
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                    .accessibilityLabel("New nutrient")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert("New Group", isPresented: $showNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Add") {
                    NutrientGroup.create(named: newGroupName, among: allGroups, in: modelContext)
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
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
                    buttonLabel: "Add",
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
                    buttonLabel: "Save",
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
            Label("No nutrients yet", systemImage: "leaf")
        } description: {
            Text("Add what you take — vitamins, supplements, water, anything.")
        } actions: {
            Button("Add a nutrient", action: startAdding)
                .buttonStyle(.borderedProminent)
                .tint(Theme.controlPrimary)
                .foregroundStyle(Theme.controlOnPrimary)
        }
    }

    private func startAdding() {
        addDraft.reset()
        addDraft.tint = NutrientTint.suggested(avoiding: nutrients.map(\.tint))
        selectedGroupForAdd = generalGroup
        showAddSheet = true
    }

    // MARK: - List

    private var nutrientList: some View {
        List {
            if let prefs = allPreferences.first, !prefs.hasSeenAnalyticsBanner {
                analyticsBanner
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(groupedSections, id: \.group.persistentModelID) { section in
                Section {
                    ForEach(section.nutrients, id: \.persistentModelID) { nutrient in
                        NavigationLink(value: nutrient.persistentModelID) {
                            nutrientRow(nutrient)
                        }
                        .listRowBackground(Theme.surfaceCard)
                        .listRowSeparatorTint(Theme.lineHairline)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                nutrientToDelete = nutrient
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                editDraft.populate(from: nutrient)
                                nutrientToEdit = nutrient
                            } label: {
                                Label("Edit", systemImage: "pencil")
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
                } header: {
                    if hasCustomGroups {
                        sectionHeader(section.group.name, count: section.nutrients.count)
                    }
                }
            }

            newGroupButton
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowSpacing(0)
    }

    private func sectionHeader(_ name: String, count: Int) -> some View {
        HStack {
            Text(name)
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            Text("\(count)")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(count) nutrients")
    }

    /// Row (DESIGN.md §5.6): icon tile, name, goal-type tag + target, bell if it has reminders.
    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        let goal = GoalProgress(nutrient: nutrient, current: 0)
        let hasReminders = !(nutrient.reminders ?? []).isEmpty

        return HStack(spacing: 12) {
            NutrientIconTile(nutrient: nutrient)

            VStack(alignment: .leading, spacing: 4) {
                Text(nutrient.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Text(GoalTypePicker.label(for: nutrient.goalType))
                        .font(.caption2.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceChip, in: RoundedRectangle(cornerRadius: Theme.Radius.tag, style: .continuous))

                    Text(goal.goalAmountText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)

                    if hasReminders {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("Has reminders")
                    }
                }
            }
        }
    }

    private var newGroupButton: some View {
        Button {
            newGroupName = ""
            showNewGroupAlert = true
        } label: {
            Label("New group", systemImage: "folder.badge.plus")
                .font(.headline)
                .foregroundStyle(Theme.controlPrimary)  // forest in light, green in dark (forest vanishes on dark)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.controlGhostBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Analytics Banner

    private var analyticsBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(Theme.controlPrimary)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tap a nutrient to see your stats")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Swipe or long-press to edit, move, or delete.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                withAnimation(.unlessReduceMotion(reduceMotion)) {
                    allPreferences.first?.hasSeenAnalyticsBanner = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-12)  // keep the visual layout; only the hit area grows
            .accessibilityLabel("Dismiss tip")
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
    }

    // MARK: - Actions

    private func addNutrient() {
        addDraft.insertNutrient(into: modelContext, group: selectedGroupForAdd ?? generalGroup, sortOrder: nutrients.count)
    }

    private func applyEdit(to nutrient: Nutrient) {
        editDraft.apply(to: nutrient)
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
