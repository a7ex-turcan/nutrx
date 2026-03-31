import SwiftUI
import SwiftData

struct NutrientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allReminders: [NutrientReminder]
    @Query(sort: \NutrientGroup.sortOrder) private var allGroups: [NutrientGroup]
    @Bindable var draft: NutrientDraft
    let title: String
    let buttonLabel: String
    var nutrient: Nutrient?
    @Binding var selectedGroup: NutrientGroup?
    var showGroupPicker: Bool = false
    var onDelete: (() -> Void)?
    let onSave: () -> Void

    @State private var showRemindersSheet = false
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var showTimePicker = false
    @State private var selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var showDeniedAlert = false

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
                VStack(spacing: 24) {
                    NutrientFormFields(draft: draft)

                    if showGroupPicker {
                        groupPickerSection
                    }

                    if let nutrient {
                        remindersSection(for: nutrient)
                    } else {
                        pendingRemindersSection
                    }

                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Text(buttonLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!draft.isValid)

                    if let onDelete {
                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            Text("Delete Nutrient")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showRemindersSheet) {
                if let nutrient {
                    NutrientRemindersSheet(nutrient: nutrient)
                }
            }
        }
    }

    private var groupPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Picker("Group", selection: $selectedGroup) {
                    ForEach(allGroups, id: \.persistentModelID) { group in
                        Text(group.name).tag(Optional(group))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    newGroupName = ""
                    showNewGroupAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Add") {
                createGroup()
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let maxOrder = allGroups.filter { !$0.isSystem }.map(\.sortOrder).max() ?? -1
        let group = NutrientGroup(name: name, sortOrder: maxOrder + 1)
        modelContext.insert(group)
        selectedGroup = group
    }

    private var pendingRemindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminders")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(draft.pendingReminderTimes, id: \.timeIntervalSinceReferenceDate) { time in
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)

                        Text(time, format: .dateTime.hour().minute())
                            .font(.body)

                        Spacer()

                        Button {
                            draft.pendingReminderTimes.removeAll { $0 == time }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if time != draft.pendingReminderTimes.last {
                        Divider().padding(.leading, 12)
                    }
                }

                if showTimePicker {
                    if !draft.pendingReminderTimes.isEmpty {
                        Divider().padding(.leading, 12)
                    }

                    VStack(spacing: 10) {
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )

                        Button {
                            addPendingReminder()
                        } label: {
                            Text("Add Reminder")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                withAnimation { showTimePicker.toggle() }
            } label: {
                Label(
                    showTimePicker ? "Cancel" : "Add Reminder",
                    systemImage: showTimePicker ? "xmark" : "plus.circle"
                )
                .font(.subheadline)
            }
        }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To set reminders, please enable notifications for nutrx in your device settings.")
        }
    }

    private func addPendingReminder() {
        Task {
            let status = await NotificationService.permissionStatus()

            switch status {
            case .notDetermined:
                let granted = await NotificationService.requestPermission()
                guard granted else { return }

            case .granted:
                break

            case .denied:
                showDeniedAlert = true
                return
            }

            draft.pendingReminderTimes.append(selectedTime)
            draft.pendingReminderTimes.sort { lhs, rhs in
                let lc = Calendar.current.dateComponents([.hour, .minute], from: lhs)
                let rc = Calendar.current.dateComponents([.hour, .minute], from: rhs)
                return (lc.hour!, lc.minute!) < (rc.hour!, rc.minute!)
            }

            withAnimation {
                showTimePicker = false
                selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
            }
        }
    }

    private func remindersSection(for nutrient: Nutrient) -> some View {
        Button {
            showRemindersSheet = true
        } label: {
            HStack {
                Label("Reminders", systemImage: "bell")
                    .font(.subheadline.weight(.medium))

                Spacer()

                let count = allReminders.filter { $0.nutrient?.persistentModelID == nutrient.persistentModelID }.count
                Text(count == 0 ? "None" : "\(count) reminder\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NutrientFormView(
        draft: NutrientDraft(),
        title: "New Nutrient",
        buttonLabel: "Add Nutrient"
    ) {}
}
