import SwiftUI
import SwiftData

struct NutrientsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Nutrient> { !$0.isRemoved },
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
    @State private var nutrientToStack: Nutrient?
    @State private var showNewGroupAlert = false
    /// Selecting several (#98): the edit mode, the selection, and the sheets for the selection.
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var showMoveSelection = false
    @State private var confirmDeleteSelection = false
    /// The selection as it was when the sheet or alert opened: ending the selection as they close would otherwise
    /// flash "Move 0 Nutrients" (and a check on every group) or "Delete 0 nutrients" on the way out.
    @State private var actingOn: [Nutrient] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var newGroupName = ""
    @Query private var allPreferences: [UserPreferences]

    private var generalGroup: NutrientGroup? {
        allGroups.first(where: { $0.isSystem })
    }

    private var hasCustomGroups: Bool {
        allGroups.contains(where: { !$0.isSystem })
    }

    /// Nutrients whose course has ended (#99), newest first: the Finished section, off Today.
    private var finishedNutrients: [Nutrient] {
        nutrients.filter { $0.hasEnded() }.sorted { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) }
    }

    @State private var showsFinished = false

    private var groupedSections: [(group: NutrientGroup, nutrients: [Nutrient])] {
        var sectionMap: [PersistentIdentifier: [Nutrient]] = [:]
        for nutrient in nutrients where !nutrient.hasEnded() {
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

    /// Pushed analytics; set by a refill reminder.
    @State private var path: [PersistentIdentifier] = []
    @Environment(NotificationRouter.self) private var router: NotificationRouter?

    var body: some View {
        NavigationStack(path: $path) {
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
                if !nutrients.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation(.unlessReduceMotion(reduceMotion, .default)) {
                                if isSelecting { endSelecting() } else { editMode = .active }
                            }
                        }
                        .fontWeight(isSelecting ? .semibold : .regular)
                    }
                }
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
            .onChange(of: router?.healthNutrientID, initial: true) { _, id in
                // Today's Apple Health card: that nutrient's analytics, which scrolls to its Health card.
                if let id, let nutrient = nutrients.first(where: { $0.id == id }) {
                    path = [nutrient.persistentModelID]
                }
            }
            .onChange(of: router?.supplyNutrientID, initial: true) { _, id in
                // A refill reminder: show that nutrient's analytics (its Supply card focuses itself).
                if let id, let nutrient = nutrients.first(where: { $0.id == id }) {
                    path = [nutrient.persistentModelID]
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
                    buttonLabel: "Add",
                    selectedGroup: $selectedGroupForAdd,
                    showGroupPicker: true,
                    offersScan: true
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
            .sheet(isPresented: $showMoveSelection) {
                MoveToGroupSheet(nutrients: actingOn) {
                    endSelecting()
                }
            }
            .alert(actingOn.count == 1 ? "Delete 1 nutrient?" : "Delete \(actingOn.count) nutrients?",
                   isPresented: $confirmDeleteSelection) {
                Button("Delete", role: .destructive) { deleteSelection() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(actingOn.count == 1
                     ? "It'll be removed from your daily tracking. Your logged history stays."
                     : "They'll be removed from your daily tracking. Your logged history stays.")
            }
            .sheet(item: $nutrientToStack) { nutrient in
                StackPickerSheet(mode: .nutrient(nutrient))
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
                        nutrient.isRemoved = true
                        nutrientToDelete = nil
                        // Its pending reminders go now, not at the next foreground.
                        try? modelContext.save()
                        NotificationService.refreshAllNutrientReminders(context: modelContext)
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
        // No selection binding outside selecting: even an empty one made a tap select the row instead of opening its
        // analytics (the rows' link values are the same type).
        List(selection: isSelecting ? $selection : nil) {
            if !isSelecting, let prefs = allPreferences.first, !prefs.hasSeenAnalyticsBanner {
                analyticsBanner
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(groupedSections, id: \.group.persistentModelID) { section in
                Section {
                    ForEach(section.nutrients, id: \.persistentModelID) { nutrient in
                        Group {
                            // While selecting a tap selects, so the row has no link and no chevron, which leaves the
                            // text room beside the selection circle and drag handle (#108).
                            if isSelecting {
                                nutrientRow(nutrient)
                            } else {
                                NavigationLink(value: nutrient.persistentModelID) {
                                    nutrientRow(nutrient)
                                }
                            }
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

                            Button {
                                nutrientToStack = nutrient
                            } label: {
                                Label("Add to Stack…", systemImage: "square.stack.3d.up")
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

            // Not while selecting: Move and Delete act on the groups' nutrients.
            if !isSelecting, !finishedNutrients.isEmpty {
                finishedSection
            }

            if !isSelecting {
                newGroupButton
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowSpacing(0)
        .environment(\.editMode, $editMode)
        // The selection circles in the app's colour rather than grey; only while selecting, or the swipe Delete
        // (destructive, untinted) turned green.
        .tint(isSelecting ? Theme.controlPrimary : nil)
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionBar
            }
        }
    }

    // MARK: - Selecting several (#98)

    private var isSelecting: Bool { editMode.isEditing }

    /// The selection in the list's order, so a move keeps it.
    private var selectedNutrients: [Nutrient] {
        groupedSections.flatMap(\.nutrients).filter { selection.contains($0.persistentModelID) }
    }

    private var selectionBar: some View {
        let count = selection.count
        let selectable = nutrients.filter { !$0.hasEnded() }
        let allSelected = count == selectable.count
        return VStack(spacing: 10) {
            HStack {
                Button(allSelected ? "Deselect All" : "Select All") {
                    selection = allSelected ? [] : Set(selectable.map(\.persistentModelID))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                Spacer()
                Text(count == 1 ? "1 selected" : "\(count) selected")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            // Side by side, or stacked at accessibility sizes so "Move to Group" isn't cut short.
            let actions = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            actions {
                Button {
                    actingOn = selectedNutrients
                    showMoveSelection = true
                } label: {
                    Label("Move to Group", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(Theme.controlOnPrimary)
                        .background(Theme.controlPrimary,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .accessibilityLabel(count == 1 ? "Move 1 nutrient to a group" : "Move \(count) nutrients to a group")
                Button(role: .destructive) {
                    actingOn = selectedNutrients
                    confirmDeleteSelection = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.red)
                        .background(Color.red.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .accessibilityLabel(count == 1 ? "Delete 1 nutrient" : "Delete \(count) nutrients")
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.surfaceGround)
    }

    private func endSelecting() {
        selection = []
        editMode = .inactive
    }

    /// Soft-deletes the selection like a single delete, saving and rescheduling reminders once.
    private func deleteSelection() {
        for nutrient in actingOn {
            nutrient.isRemoved = true
        }
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
        withAnimation(.unlessReduceMotion(reduceMotion, .default)) { endSelecting() }
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
        .accessibilityLabel("\(name), \(count == 1 ? "1 nutrient" : "\(count) nutrients")")
    }

    /// Row (DESIGN.md §5.6): icon tile, name, goal-type tag + target, bell if it has reminders.
    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        let goal = GoalProgress(nutrient: nutrient, current: 0)
        // A finished course's reminders have stopped.
        let hasReminders = !(nutrient.reminders ?? []).isEmpty && !nutrient.hasEnded()

        // At accessibility sizes there's no room beside the name (less still in Select mode, with the selection circle
        // and drag handle): no icon tile, and the tag and target go under it, so nothing breaks mid-word (#108).
        let large = dynamicTypeSize.isAccessibilitySize
        let details = large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))

        return HStack(spacing: 12) {
            if !large {
                NutrientIconTile(nutrient: nutrient)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(nutrient.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    // At most one line per word, so a word too long for the row ("Magnesium", "Omega-3",
                    // "Magnesium glycinate") shrinks rather than breaking mid-word; names still wrap between words.
                    .lineLimit(large ? max(nutrient.name.split(separator: " ").count, 1) : nil)
                    .minimumScaleFactor(large ? 0.5 : 1)

                details {
                    Text(GoalTypePicker.label(for: nutrient.goalType))
                        .font(.caption2.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceChip, in: RoundedRectangle(cornerRadius: Theme.Radius.tag, style: .continuous))
                        .fixedSize()

                    if let endDate = nutrient.endDate, nutrient.hasEnded() {
                        Text(CourseText().ended(endDate))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(goal.goalAmountText)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            // In Select mode's narrower row, a range ("120–160 g") shrinks a little rather than splitting
                            // at the dash; the full-width list has room for it.
                            .lineLimit(large && isSelecting ? 1 : nil)
                            .minimumScaleFactor(large && isSelecting ? 0.7 : 1)
                    }

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

    // MARK: - Finished (#99)

    /// Courses that have ended, collapsed at the end: still here for analytics, and Restart puts one back on Today.
    private var finishedSection: some View {
        Section {
            if showsFinished {
                ForEach(finishedNutrients, id: \.persistentModelID) { nutrient in
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
                    .contextMenu {
                        Button {
                            restart(nutrient)
                        } label: {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        Button {
                            editDraft.populate(from: nutrient)
                            nutrientToEdit = nutrient
                        } label: {
                            Label("Edit Nutrient", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            nutrientToDelete = nutrient
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Button {
                withAnimation(.unlessReduceMotion(reduceMotion, .default)) { showsFinished.toggle() }
            } label: {
                HStack {
                    Text("Finished")
                        .font(.footnote.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(showsFinished ? 0 : -90))
                        .accessibilityHidden(true)
                    Spacer()
                    Text("\(finishedNutrients.count)")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finished, \(finishedNutrients.count == 1 ? "1 nutrient" : "\(finishedNutrients.count) nutrients")")
            .accessibilityValue(showsFinished ? "Expanded" : "Collapsed")
        }
    }

    /// Back to ongoing and onto Today; its reminders come back. The days since it ended stay a gap (`setCourse`).
    private func restart(_ nutrient: Nutrient) {
        nutrient.setCourse(endDate: nil)
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
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
        // Flat like the list's group cards below it: a list row clips `cardStyle()`'s shadow into a hard band.
        .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
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
