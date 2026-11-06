import SwiftUI
import SwiftData

/// The Stacks tab (docs/pro/design/1-stacks-export: stacks, stacks-empty): the user's stacks in Today's order with
/// their nutrients and a Log button, reorder, swipe to delete, + to create one (named first, then opened to add
/// nutrients). Logging here is the same as on Today (`TodayViewModel.logStack`: reminders, widgets, haptics).
struct StacksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    @State private var today = TodayViewModel()
    @State private var stackToLog: LogStack?

    @State private var showNewStackAlert = false
    @State private var newStackName = ""
    @State private var openedStack: LogStack?
    @State private var stackToDelete: LogStack?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if stacks.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.surfaceGround)
        .navigationTitle("Stacks")
        .navigationBarTitleDisplayMode(.large)
        // Before this view's toolbar, so + comes before the avatar and the avatar keeps its far-right spot (#100).
        .withProfileMenu()
        .toolbar {
            if !stacks.isEmpty {
                // Leading, so + and the profile menu share the trailing side, as in My Nutrients.
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // The same filled circle as My Nutrients' +. (A glassProminent button here logged "glassEffect()
                // tried to update multiple times per frame" on every push.)
                Button {
                    newStackName = ""
                    showNewStackAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.controlOnPrimary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .background(Theme.controlPrimary, in: Circle())
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
                .accessibilityLabel("New stack")
            }
            // No glass ring around the filled circle, as on My Nutrients.
            .sharedBackgroundVisibility(.hidden)
        }
        .navigationDestination(item: $openedStack) { stack in
            StackDetailView(stack: stack)
        }
        .sheet(item: $stackToLog) { stack in
            LogStackSheet(
                stack: stack,
                totalFor: { today.total(for: $0) },
                onLog: { amounts in
                    let result = today.logStack(stack, amounts: amounts, context: modelContext)
                    Haptics.logged(reachingGoal: result.reachedGoal)
                    ReviewService.checkAfterLogging(context: modelContext)
                    // Today patches its totals in place; this makes it reload (as Siri logging does).
                    NotificationCenter.default.post(name: .intakeLoggedByShortcut, object: nil)
                    return result.logged
                },
                onUndo: { logged in
                    today.undoStack(logged, of: stack, context: modelContext)
                    NotificationCenter.default.post(name: .intakeLoggedByShortcut, object: nil)
                },
                onEditStack: {
                    stackToLog = nil
                    openedStack = stack
                }
            )
        }
        .alert("New Stack", isPresented: $showNewStackAlert) {
            TextField("Stack name", text: $newStackName)
            Button("Create") { createStack() }
                .disabled(newStackName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(StackLogging.newStackMessage(existing: stacks.map(\.name)))
        }
        .confirmationDialog(
            "Delete \(stackToDelete?.name ?? "stack")?",
            isPresented: Binding(get: { stackToDelete != nil }, set: { if !$0 { stackToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Stack", role: .destructive) {
                if let stack = stackToDelete { delete(stack) }
            }
        } message: {
            Text("Your logged entries stay. Only the stack goes.")
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(stacks, id: \.persistentModelID) { stack in
                    Button {
                        openedStack = stack
                    } label: {
                        stackRow(stack)
                    }
                    .buttonStyle(.plain)
                    .accessibilityActions {
                        // Nothing to log on a day when all its nutrients are off (#132).
                        if !StackLogging.dueEntries(of: stack).isEmpty {
                            Button("Log \(stack.name)") { log(stack) }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            stackToDelete = stack
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: move)
            } footer: {
                Text("Stacks appear on Today in this order. Swipe a stack to delete it; what you logged stays.")
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .readableColumn(ownMargin: 20)  // rows were 1,336 pt wide on a 13" iPad (#151)
    }

    private func stackRow(_ stack: LogStack) -> some View {
        let nutrients = StackLogging.activeEntries(of: stack).compactMap(\.nutrient)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stack.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                if !nutrients.isEmpty, !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 6) {
                        ForEach(nutrients.prefix(5), id: \.persistentModelID) { nutrient in
                            NutrientIconTile(nutrient: nutrient, size: 24)
                        }
                    }
                }
                Text(StackLogging.summary(of: stack))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // Under the names, so they get the row's width. On a day when all its nutrients are off (#132), a
                // note instead of a Log that would log nothing.
                if !nutrients.isEmpty {
                    if StackLogging.dueEntries(of: stack).isEmpty {
                        Text("Nothing due today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 2)
                    } else {
                        logButton(stack)
                            .padding(.top, 2)
                    }
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // The separator starts at the text, whatever's inside the row.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .accessibilityElement(children: .combine)
        // The same words as the stack's card on Today, "Logged today." included once it is.
        .accessibilityLabel(StackAccessibility.label(for: stack, done: StackLogging.isLoggedToday(stack)))
        .accessibilityAddTraits(.isButton)
    }

    @ScaledMetric(relativeTo: .subheadline) private var logTickSize: CGFloat = 11

    /// "Log" (or a check and "Log again" once logged today), the same action as the stack's card on Today.
    private func logButton(_ stack: LogStack) -> some View {
        let done = StackLogging.isLoggedToday(stack)
        return Button { log(stack) } label: {
            // The tick drawn, not an SF Symbol: a checkmark image was read as "Selected" even hidden (#203).
            HStack(spacing: 6) {
                if done {
                    // Scaled with the text, like the "+" it replaces.
                    CheckmarkShape()
                        .stroke(style: StrokeStyle(lineWidth: logTickSize * 0.18, lineCap: .round, lineJoin: .round))
                        .frame(width: logTickSize, height: logTickSize * 0.73)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "plus").accessibilityHidden(true)
                }
                Text(done ? "Log again" : "Log")
            }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(done ? Theme.textPrimary : Theme.controlOnPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background {
                    if done {
                        Capsule().strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                    } else {
                        Capsule().fill(Theme.controlPrimary)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(done ? "Log \(stack.name) again" : "Log \(stack.name)")
    }

    private func log(_ stack: LogStack) {
        today.refresh(context: modelContext)
        stackToLog = stack
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Theme.forest)
                .frame(width: 76, height: 76)
                .background(Theme.green.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("Log several at once")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Make a stack of what you take together, like Morning with Vitamin D, Omega-3 and Magnesium. Then log it all with one tap, here or on Today.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                newStackName = ""
                showNewStackAlert = true
            } label: {
                Label("Create a stack", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 50)
                    .background(Theme.controlPrimary,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createStack() {
        let name = newStackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        // A name that's already a stack opens that one.
        openedStack = StackLogging.stack(named: name, in: stacks)
            ?? StackLogging.createStack(named: name, context: modelContext)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = stacks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, stack) in ordered.enumerated() {
            stack.sortOrder = index
        }
        try? modelContext.save()
    }

    private func delete(_ stack: LogStack) {
        modelContext.delete(stack)
        try? modelContext.save()
        stackToDelete = nil
        StackShortcutLogging.stacksChanged()
        // Its reminder (#137) goes with it.
        NotificationService.refreshAllNutrientReminders(context: modelContext)
    }
}

#Preview("Stacks") {
    NavigationStack {
        StacksView()
    }
    .modelContainer(previewContainer)
}
