import SwiftUI
import SwiftData

/// New / edit nutrient sheet (DESIGN.md §5.7): Cancel / title / Add in the toolbar, then a live preview,
/// the shared fields, Group and Reminders rows, and notes.
struct NutrientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allReminders: [NutrientReminder]
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]
    @Bindable var draft: NutrientDraft
    let title: String
    /// Toolbar confirm button, e.g. "Add" or "Save".
    let buttonLabel: String
    var nutrient: Nutrient?
    @Binding var selectedGroup: NutrientGroup?
    var showGroupPicker: Bool = false
    var onDelete: (() -> Void)?
    let onSave: () -> Void

    @State private var showRemindersSheet = false
    @State private var showPendingReminders = false
    @State private var showGroupChooser = false
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @FocusState private var focusedField: NutrientFormField?

    init(
        draft: NutrientDraft,
        title: String,
        buttonLabel: String,
        nutrient: Nutrient? = nil,
        selectedGroup: Binding<NutrientGroup?> = .constant(nil),
        showGroupPicker: Bool = false,
        onDelete: (() -> Void)? = nil,
        onSave: @escaping () -> Void
    ) {
        self.draft = draft
        self.title = title
        self.buttonLabel = buttonLabel
        self.nutrient = nutrient
        self._selectedGroup = selectedGroup
        self.showGroupPicker = showGroupPicker
        self.onDelete = onDelete
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.cardGap) {
                    NutrientPreviewRow(draft: draft)

                    NutrientFormFields(draft: draft, focusedField: $focusedField) {
                        settingsRows
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            Text("Delete Nutrient")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.control))
                        .padding(.top, Theme.Spacing.sectionTop)
                    }
                }
                .padding(Theme.Spacing.screenMargin)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.surfaceGround)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(buttonLabel) {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .disabled(!draft.isValid)
                }
                // Done for the return-less .decimalPad fields.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showRemindersSheet) {
                if let nutrient {
                    NutrientRemindersSheet(nutrient: nutrient)
                }
            }
            .sheet(isPresented: $showPendingReminders) {
                PendingRemindersSheet(draft: draft)
            }
            .alert("New Group", isPresented: $showNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Add") {
                    if let group = NutrientGroup.create(named: newGroupName, among: allGroups, in: modelContext) {
                        selectedGroup = group
                    }
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Group / Reminders

    private var settingsRows: some View {
        VStack(spacing: 0) {
            if showGroupPicker {
                // A dialog rather than a Menu: a Menu with this custom row as its label crashes SwiftUI's
                // layout ("accessing attribute in a different namespace") inside the form's stacks.
                Button {
                    showGroupChooser = true
                } label: {
                    settingsRow("Group", value: selectedGroup?.name ?? "General")
                }
                .buttonStyle(.plain)
                .confirmationDialog("Group", isPresented: $showGroupChooser) {
                    ForEach(allGroups, id: \.persistentModelID) { group in
                        Button(group.name) { selectedGroup = group }
                    }
                    Button("New Group…") {
                        newGroupName = ""
                        showNewGroupAlert = true
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Rectangle().fill(Theme.lineHairline).frame(height: 1)
            }

            Button {
                if nutrient == nil {
                    showPendingReminders = true
                } else {
                    showRemindersSheet = true
                }
            } label: {
                settingsRow("Reminders", value: remindersSummary)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var remindersSummary: String {
        let count: Int
        if let nutrient {
            count = allReminders.filter { $0.nutrient?.persistentModelID == nutrient.persistentModelID }.count
        } else {
            count = draft.pendingReminderTimes.count
        }
        switch count {
        case 0: return "None"
        case 1: return "1 reminder"
        default: return "\(count) reminders"
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                // Value under the title, so neither is cut short or broken mid-word.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Theme.textPrimary)
                    Text(value)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            } else {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct NutrientFormPreview: View {
    @State private var draft: NutrientDraft = {
        let draft = NutrientDraft()
        draft.name = "Creatine"
        draft.unit = "g"
        draft.dailyTarget = "5"
        draft.step = "5"
        draft.tint = .teal
        draft.symbolName = "waterbottle"
        return draft
    }()

    var body: some View {
        NutrientFormView(draft: draft, title: "New Nutrient", buttonLabel: "Add", showGroupPicker: true) {}
            .modelContainer(previewContainer)
    }
}

#Preview("Light") {
    NutrientFormPreview()
}

#Preview("Dark") {
    NutrientFormPreview()
        .preferredColorScheme(.dark)
}
