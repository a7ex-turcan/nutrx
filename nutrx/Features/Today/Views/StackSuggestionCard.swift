import SwiftUI

/// Today's pointer to stacks before there are any (shown with three or more nutrients, until a stack exists or it's
/// hidden): what a stack is, "Make a stack", and ✕. Making one names it and opens it to add nutrients.
struct StackSuggestionCard: View {
    let onMake: () -> Void
    let onHide: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    NutrientIconTile(tint: .teal, symbolName: "square.stack.3d.up", size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Log several at once")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Make a stack, like Morning, of what you take together, then log it all with one tap.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onHide) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -10)
                .padding(.trailing, -10)
                .accessibilityLabel("Hide this suggestion")
            }
            Button(action: onMake) {
                Label("Make a stack", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.controlPrimary,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
    }
}

#Preview {
    StackSuggestionCard(onMake: {}, onHide: {})
        .padding()
        .background(Theme.surfaceGround)
}
