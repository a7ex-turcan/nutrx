import SwiftUI
import SwiftData

struct NutrientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allReminders: [NutrientReminder]
    @Bindable var draft: NutrientDraft
    let title: String
    let buttonLabel: String
    var nutrient: Nutrient?
    var onDelete: (() -> Void)?
    let onSave: () -> Void

    @State private var showRemindersSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    NutrientFormFields(draft: draft)

                    if let nutrient {
                        remindersSection(for: nutrient)
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
