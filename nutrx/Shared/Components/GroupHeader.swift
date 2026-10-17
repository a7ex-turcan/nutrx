import SwiftUI

/// Collapsible group header on Today: name, "2/3" met chip and chevron (DESIGN.md §4.5).
/// Hidden by the caller when only the system group exists.
struct GroupHeader: View {
    let name: String
    let met: Int
    let total: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("\(met)/\(total)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.surfaceChip, in: Capsule())

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
