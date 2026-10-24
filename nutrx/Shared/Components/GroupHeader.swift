import SwiftUI

/// Collapsible group header on Today: name, "2/3" met chip and chevron (DESIGN.md §4.5).
/// Hidden by the caller when only the system group exists.
struct GroupHeader: View {
    let name: String
    let met: Int
    let total: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the chip goes under the name, which then has the row up to the chevron, and a word
        // still too long for it shrinks rather than breaking mid-word ("Throug / h the / day" at AX5, #273).
        let large = dynamicTypeSize.isAccessibilitySize
        let title = large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 10))

        Button(action: onToggle) {
            HStack(spacing: 10) {
                title {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        // At most one line per word, as My Nutrients' rows (#108); names still wrap between words.
                        .lineLimit(large ? max(name.split(separator: " ").count, 1) : nil)
                        .minimumScaleFactor(large ? 0.5 : 1)

                    Text("\(met)/\(total)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceChip, in: Capsule())
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(met) of \(total) \(GoalProgress.goals(total)) met")
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
        .accessibilityHint("Shows or hides this group")
        .accessibilityAddTraits([.isHeader, .isButton])  // children: .ignore can drop the button's own trait
    }
}

// MARK: - Previews

private struct GroupHeaderPreviewGallery: View {
    @State private var collapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(name: "Morning stack", met: 2, total: 3, isCollapsed: collapsed) {
                withAnimation(.easeInOut(duration: 0.25)) { collapsed.toggle() }
            }
            GroupHeader(name: "Through the day", met: 1, total: 3, isCollapsed: true) {}
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    GroupHeaderPreviewGallery()
}

#Preview("Dark") {
    GroupHeaderPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    GroupHeaderPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5") {
    GroupHeaderPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
}
