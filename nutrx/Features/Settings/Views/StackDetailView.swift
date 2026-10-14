import SwiftUI
import SwiftData

/// One stack (docs/pro/design/1-stacks-export: stack-detail): its name, its nutrients with the amount each one logs
/// (− / + by the nutrient's step, drag to reorder, swipe to remove), Add nutrient, and Delete stack.
struct StackDetailView: View {
    @Bindable var stack: LogStack

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddNutrient = false
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var entries: [LogStackEntry] { StackLogging.activeEntries(of: stack) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Name")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)  // the field's own label
                    TextField("e.g. Morning", text: $stack.name)
                        .font(.title3.weight(.semibold))
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .accessibilityLabel("Name")
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                ForEach(entries, id: \.persistentModelID) { entry in
                    entryRow(entry)
                }
                .onMove(perform: move)

                Button {
                    showAddNutrient = true
                } label: {
                    Label("Add nutrient", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.controlPrimary)
                        .frame(minHeight: Theme.minTouchTarget)
                }
            } header: {
                Text("Nutrients & amounts")
                    .textCase(.uppercase)
            } footer: {
                Text("Amounts start at each nutrient's step. You can still change them each time you log.")
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("Delete stack")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .navigationTitle("Stack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddNutrient) {
            AddStackNutrientSheet(stack: stack)
        }
        .confirmationDialog("Delete \(stack.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Stack", role: .destructive) {
                modelContext.delete(stack)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Your logged entries stay. Only the stack goes.")
        }
        .onChange(of: nameFocused) { _, focused in
            // An emptied name falls back to "Stack" rather than leaving a blank card on Today.
            if !focused {
                let trimmed = stack.name.trimmingCharacters(in: .whitespacesAndNewlines)
                stack.name = trimmed.isEmpty ? "Stack" : trimmed
                try? modelContext.save()
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    private func entryRow(_ entry: LogStackEntry) -> some View {
        let nutrient = entry.nutrient!  // active entries always have one
        let name = HStack(spacing: 12) {
            NutrientIconTile(nutrient: nutrient, size: 40)
            Text(nutrient.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        let stepper = StackAmountStepper(amount: entry.amount, step: nutrient.step, unit: nutrient.unit,
                                         nutrientName: nutrient.name) {
            entry.amount = $0
        }
        let stacked = VStack(alignment: .leading, spacing: 10) {
            name
            stepper
        }
        return Group {
            // The amount goes under the name whenever the name wouldn't fit on one line beside it (accessibility
            // sizes, long names, the reorder handle in edit mode), so the name is never broken mid-word.
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        name.fixedSize()
                        Spacer(minLength: 8)
                        stepper
                    }
                    stacked
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                remove(entry)
            } label: {
                Label("Remove", systemImage: "minus.circle")
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = entries
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in ordered.enumerated() {
            entry.sortOrder = index
        }
        try? modelContext.save()
    }

    private func remove(_ entry: LogStackEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

/// Picks a nutrient to add to a stack: the user's nutrients in Today's order, minus those already in it.
private struct AddStackNutrientSheet: View {
    let stack: LogStack

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let inStack = Set(StackLogging.activeEntries(of: stack).compactMap { $0.nutrient?.persistentModelID })
        let available = NutrientEntityQuery.activeNutrients(in: modelContext)
            .filter { !inStack.contains($0.persistentModelID) }
        NavigationStack {
            List {
                if available.isEmpty {
                    Text("Every nutrient is already in this stack.")
                        .foregroundStyle(Theme.textSecondary)
                        .listRowBackground(Theme.surfaceCard)
                } else {
                    ForEach(available, id: \.persistentModelID) { nutrient in
                        Button {
                            StackLogging.add(nutrient, to: stack, context: modelContext)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                NutrientIconTile(nutrient: nutrient, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(nutrient.name)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(nutrient.step.formattedAmount()) \(nutrient.unit) a step")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds it to \(stack.name)")
                        .listRowBackground(Theme.surfaceCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceGround)
            .navigationTitle("Add Nutrient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
