import SwiftUI
import SwiftData

/// Settings → Stacks (docs/pro/design/1-stacks-export: stacks, stacks-empty): the user's stacks in Today's order
/// with their nutrients, reorder, swipe to delete, + to create one (named first, then opened to add nutrients).
struct StacksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]

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
        .toolbar {
            if !stacks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
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
        }
        .navigationDestination(item: $openedStack) { stack in
            StackDetailView(stack: stack)
        }
        .alert("New Stack", isPresented: $showNewStackAlert) {
            TextField("Stack name", text: $newStackName, prompt: Text("e.g. Morning"))
            Button("Create") { createStack() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name it after when you take it.")
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
                Text("Stacks appear on Today in this order. Swipe a stack to delete it.")
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func stackRow(_ stack: LogStack) -> some View {
        let nutrients = StackLogging.activeEntries(of: stack).compactMap(\.nutrient)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stack.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                let tiles = HStack(spacing: 6) {
                    ForEach(nutrients.prefix(4), id: \.persistentModelID) { nutrient in
                        NutrientIconTile(nutrient: nutrient, size: 24)
                    }
                }
                let names = Text(StackLogging.summary(of: stack))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                if dynamicTypeSize.isAccessibilitySize {
                    tiles
                    names
                } else {
                    HStack(spacing: 6) {
                        tiles
                        names.lineLimit(2)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stack.name): \(StackLogging.summary(of: stack))")
        .accessibilityAddTraits(.isButton)
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
            Text("No stacks yet")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("A stack logs several nutrients in one tap — everything you take with breakfast, for example.")
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
        openedStack = StackLogging.createStack(named: name, context: modelContext)
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
    }
}

#Preview("Stacks") {
    NavigationStack {
        StacksView()
    }
    .modelContainer(previewContainer)
}
