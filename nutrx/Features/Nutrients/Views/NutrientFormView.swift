import SwiftUI

struct NutrientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var draft: NutrientDraft
    let title: String
    let buttonLabel: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    NutrientFormFields(draft: draft)

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
        }
    }
}

#Preview {
    NutrientFormView(
        draft: NutrientDraft(),
        title: "New Nutrient",
        buttonLabel: "Add Nutrient"
    ) {}
}
