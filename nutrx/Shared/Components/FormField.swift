import SwiftUI

/// Labeled form field with consistent styling used across the app.
/// Wraps any input control with a label and the standard card background. The caption is visual only: give the
/// control its own accessibility label (a text field's placeholder alone isn't a name).
struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)

            content
                .padding(12)
                .background(Theme.surfaceCard,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FormField(label: "Name") {
            TextField("Your name", text: .constant(""))
                .accessibilityLabel("Name")
        }
        FormField(label: "Weight") {
            HStack {
                TextField("0", text: .constant(""))
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Weight")
            }
        }
    }
    .padding(24)
    .background(Theme.surfaceGround)
}
