import SwiftUI

struct CustomAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let nutrient: Nutrient
    let onSave: (Double, String?) -> Void

    @State private var amountText: String = ""
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool

    private var amount: Double? {
        guard let value = amountText.parsedDouble, value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Add Exact Amount")
                        .font(.headline)

                    Text("Enter the amount of \(nutrient.name) to add, in \(nutrient.unit).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                FormField(label: "Amount (\(nutrient.unit))") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                }

                FormField(label: "Note (optional)") {
                    TextField("e.g. with breakfast", text: $noteText)
                }

                Button {
                    if let amount {
                        let note = noteText.trimmingCharacters(in: .whitespaces)
                        onSave(amount, note.isEmpty ? nil : note)
                        dismiss()
                    }
                } label: {
                    Text("Add")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount == nil)

                Spacer()
            }
            .padding(24)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CustomAmountSheet(
        nutrient: Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
    ) { _, _ in }
}
