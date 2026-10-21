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
    /// Set by Delete stack: the stack is deleted once this screen is gone, so its body never reads a deleted model.
    @State private var deleteOnDisappear = false
    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The Siri tip's ✕ hides it on this device for every stack.
    @AppStorage("hidesStackSiriTip") private var hidesSiriTip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    // Not a Label: at accessibility sizes its title wrapped back under the icon.
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                        Text("Add nutrient")
                    }
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

            if !hidesSiriTip && !entries.isEmpty {
                Section {
                    StackSiriTip(stackName: stack.name) {
                        withAnimation(.unlessReduceMotion(reduceMotion, .default)) { hidesSiriTip = true }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

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
        .readableColumn(ownMargin: 20)
        .background(Theme.surfaceGround)
        .navigationTitle("Stack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAddNutrient) {
            AddStackNutrientSheet(stack: stack)
        }
        .confirmationDialog("Delete \(stack.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Stack", role: .destructive) {
                deleteOnDisappear = true
                dismiss()
            }
        } message: {
            Text("Your logged entries stay. Only the stack goes.")
        }
        .onChange(of: nameFocused) { _, focused in
            if !focused {
                commitName()
            }
        }
        .onDisappear {
            if deleteOnDisappear {
                modelContext.delete(stack)
                try? modelContext.save()
            } else {
                // Also covers closing the sheet while the name field still has focus.
                commitName()
            }
            StackShortcutLogging.stacksChanged()
        }
    }

    /// Trims the name and saves; an emptied name falls back to "Stack" rather than leaving a blank card on Today.
    private func commitName() {
        let trimmed = stack.name.trimmingCharacters(in: .whitespacesAndNewlines)
        stack.name = trimmed.isEmpty ? "Stack" : trimmed
        try? modelContext.save()
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

/// "Say “Log my Morning stack with nutrx” to Siri" (docs/pro/design/1-stacks-export: stack-detail): Forest @ 6%
/// (Card in dark), a waveform tile and a ✕ that hides it. The phrase is the first "Log Stack" App Shortcut phrase,
/// app name included, since Siri only runs an app's phrases when they name the app.
private struct StackSiriTip: View {
    let stackName: String
    let onHide: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            // At accessibility sizes the text gets the card's full width under the tile and ✕.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        tile
                        Spacer(minLength: 8)
                        hideButton
                    }
                    text
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    tile
                    text
                    hideButton
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(colorScheme == .dark ? Theme.surfaceCard : Theme.forest.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.tip, style: .continuous))
    }

    private var tile: some View {
        let dark = colorScheme == .dark
        return Image(systemName: "waveform")
            .font(.body.weight(.semibold))
            .foregroundStyle(dark ? Theme.green : Theme.forest)
            .frame(width: 36, height: 36)
            .background(dark ? Theme.green.opacity(0.15) : Theme.surfaceCard,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Say “\(StackShortcutLogging.siriPhrase(for: stackName))” to Siri")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Also works from the Shortcuts app.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var hideButton: some View {
        Button(action: onHide) {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, height: 32)
                // A 44pt hit area around the 32pt glyph box, without making the row taller.
                .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                .contentShape(Rectangle())
                .padding(-(Theme.minTouchTarget - 32) / 2)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("Hide Siri tip")
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
                                    Text(nutrient.unit.isEmpty
                                         ? "\(nutrient.step.formattedAmount()) a step"
                                         : "\(nutrient.step.formattedAmount()) \(nutrient.unit) a step")
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

private struct StackDetailPreview: View {
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]

    var body: some View {
        if let stack = stacks.first {
            NavigationStack {
                StackDetailView(stack: stack)
            }
        }
    }
}

#Preview("Stack") {
    StackDetailPreview()
        .modelContainer(previewContainer)
}

#Preview("Stack, Accessibility 3") {
    StackDetailPreview()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
