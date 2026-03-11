import SwiftUI

/// Labeled form field with consistent styling used across the app.
/// Wraps any input control with a label and the standard card background.
struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            content
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FormField(label: "Name") {
            TextField("Your name", text: .constant(""))
        }
        FormField(label: "Weight") {
            HStack {
                TextField("0", text: .constant(""))
                    .keyboardType(.decimalPad)
            }
        }
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
