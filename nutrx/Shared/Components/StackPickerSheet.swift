import SwiftData
import SwiftUI

/// Picks the stacks a nutrient is in, with "New Stack…": from My Nutrients' long-press ("Add to Stack…", changes at
/// once) and from the new-nutrient form (kept on the draft and applied when the nutrient is added). A nutrient joins a
/// stack at one step; the amount is changed in the stack itself (Settings → Stacks).
struct StackPickerSheet: View {
    enum Mode {
        /// A saved nutrient: each tap adds it to or takes it out of that stack.
        case nutrient(Nutrient)
        /// A nutrient that isn't saved yet: the choices go on the draft.
        case draft(NutrientDraft)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    @State private var showNewStack = false
    @State private var newStackName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(stacks, id: \.persistentModelID) { stack in
                        row(stack.name, isSelected: isSelected(stack)) { toggle(stack) }
                    }
                    if case .draft(let draft) = mode {
                        ForEach(newNames(draft), id: \.self) { name in
                            row(name, isSelected: true) { draft.pendingStacks.removeAll { $0 == .new(name) } }
                        }
                    }
                    Button {
                        newStackName = ""
                        showNewStack = true
                    } label: {
                        Label("New Stack…", systemImage: "plus")
                    }
                } footer: {
                    Text(footer)
                }
                .listRowBackground(Theme.surfaceCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("New Stack", isPresented: $showNewStack) {
                TextField(StackLogging.suggestedName(existing: stacks.map(\.name) + pendingNewNames), text: $newStackName)
                Button("Create") { createStack() }
                    .disabled(newStackName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(StackLogging.newStackMessage)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        if case .nutrient(let nutrient) = mode { return "Add \(nutrient.name) to a Stack" }
        return "Stacks"
    }

    private var footer: String {
        let name: String = switch mode {
        case .nutrient(let nutrient): nutrient.name
        case .draft(let draft): draft.name.trimmingCharacters(in: .whitespaces).isEmpty ? "It" : draft.name
        }
        return "\(name) joins at one step each time the stack is logged. Change the amount in the stack itself."
    }

    private func row(_ name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.controlPrimary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func isSelected(_ stack: LogStack) -> Bool {
        switch mode {
        case .nutrient(let nutrient): StackLogging.contains(stack, nutrient)
        case .draft(let draft): draft.pendingStacks.contains(.existing(stack.id))
        }
    }

    private var pendingNewNames: [String] {
        if case .draft(let draft) = mode { return newNames(draft) }
        return []
    }

    private func newNames(_ draft: NutrientDraft) -> [String] {
        draft.pendingStacks.compactMap { if case .new(let name) = $0 { name } else { nil } }
    }

    private func toggle(_ stack: LogStack) {
        switch mode {
        case .nutrient(let nutrient):
            StackLogging.toggle(nutrient, in: stack, context: modelContext)
            StackShortcutLogging.stacksChanged()
        case .draft(let draft):
            if let index = draft.pendingStacks.firstIndex(of: .existing(stack.id)) {
                draft.pendingStacks.remove(at: index)
            } else {
                draft.pendingStacks.append(.existing(stack.id))
            }
        }
    }

    private func createStack() {
        let name = newStackName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        switch mode {
        case .nutrient(let nutrient):
            let stack = StackLogging.createStack(named: name, context: modelContext)
            StackLogging.add(nutrient, to: stack, context: modelContext)
            StackShortcutLogging.stacksChanged()
        case .draft(let draft):
            // Created with the nutrient, so Cancel on the form leaves no empty stack behind.
            if !draft.pendingStacks.contains(.new(name)) { draft.pendingStacks.append(.new(name)) }
        }
    }
}
