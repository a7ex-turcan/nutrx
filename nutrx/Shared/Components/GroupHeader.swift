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
        // still too long for it makes the name smaller rather than breaking mid-word ("Throug / h the / day" at AX5,
        // #273).
        let large = dynamicTypeSize.isAccessibilitySize
        let title = large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 10))

        Button(action: onToggle) {
            HStack(spacing: 10) {
                title {
                    if large {
                        // The largest size whose widest word fits the row: shrinking the text only when it overflows
                        // its lines would still give "Supplementa- / tion stack", which fits in two.
                        ViewThatFits(in: .horizontal) {
                            nameText(upTo: .accessibility5)
                            nameText(upTo: .accessibility3)
                            nameText(upTo: .accessibility1)
                            nameText(upTo: .xxxLarge)
                        }
                    } else {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                    }

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

    /// The name at accessibility sizes, at most `size`. Its ideal width is its widest word's, which `ViewThatFits`
    /// compares with the row; laid out, it wraps between words in the width it's given.
    private func nameText(upTo size: DynamicTypeSize) -> some View {
        let words = name.split(separator: " ")
        return ZStack(alignment: .topLeading) {
            // Every word, since the most letters isn't the widest ("WOMEN" is wider than "illicit"); one line each, so
            // a word too wide even at the last step doesn't add height under the shrunk name.
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .lineLimit(1)
                    .hidden()
            }
            Text(name)
                .foregroundStyle(Theme.textPrimary)
                // A single word too long even at the smallest step shrinks rather than breaking.
                .lineLimit(max(words.count, 1))
                .minimumScaleFactor(0.5)
                .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .font(.headline)
        .dynamicTypeSize(...size)
    }
}

// MARK: - Previews

private struct GroupHeaderPreviewGallery: View {
    @State private var collapsed = false

    var body: some View {
        // Scrolling, like Today's list: in a fixed height the names would shrink to fit it instead.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GroupHeader(name: "Morning stack", met: 2, total: 3, isCollapsed: collapsed) {
                    withAnimation(.easeInOut(duration: 0.25)) { collapsed.toggle() }
                }
                GroupHeader(name: "Through the day", met: 1, total: 3, isCollapsed: true) {}
                // A word too long for the row at the largest sizes, alone and with others.
                GroupHeader(name: "Supplementation", met: 0, total: 4, isCollapsed: false) {}
                GroupHeader(name: "Supplementation stack", met: 0, total: 4, isCollapsed: false) {}
                // Too wide even at the last step: it shrinks onto one line.
                GroupHeader(name: "Electrolytesupplementation", met: 0, total: 2, isCollapsed: false) {}
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
        }
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
