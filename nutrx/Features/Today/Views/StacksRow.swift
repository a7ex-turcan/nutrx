import SwiftUI
import SwiftData

/// Today's "Stacks" row (docs/pro/design/1-stacks-export): a header with Edit, then one card per stack. Several
/// stacks scroll sideways as 176pt cards; a single stack is one full-width card; at accessibility sizes every stack
/// is a full-width card, stacked (`largest-text.png`). A stack logged today shows a check and "Log again".
struct StacksRow: View {
    /// How the cards are laid out: the iPhone's sideways row, equal tiles three to a row at regular widths, or a
    /// vertical list of one-stack cards in the wide layout's side column (docs/design/large-screens, #152).
    enum Layout { case row, tiles, list }

    let stacks: [LogStack]
    var layout: Layout = .row
    /// The header's and cards' side margin: the screen margin on iPhone, none where the page sets its own.
    var horizontalMargin: CGFloat = Theme.Spacing.screenMargin
    /// The gap between tiles, matching the card columns' gutter (16 pt, 20 on wide).
    var tileGutter: CGFloat = 16
    let onLog: (LogStack) -> Void
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // The Edit button's 44pt hit area already spaces the header from the cards.
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Stacks")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget)
                    .accessibilityLabel("Edit stacks")
            }
            .padding(.horizontal, horizontalMargin)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(stacks, id: \.persistentModelID) { stack in
                        LargeTextStackCard(stack: stack, onLog: { onLog(stack) })
                    }
                }
                .padding(.horizontal, horizontalMargin)
            } else if layout == .list || stacks.count == 1 {
                VStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(stacks, id: \.persistentModelID) { stack in
                        SingleStackCard(stack: stack, onLog: { onLog(stack) })
                    }
                }
                .padding(.horizontal, horizontalMargin)
            } else if layout == .tiles {
                // Equal tiles, three to a row, each row as tall as its tallest card.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: tileGutter, alignment: .top),
                                         count: 3),
                          spacing: tileGutter) {
                    ForEach(stacks, id: \.persistentModelID) { stack in
                        StackCard(stack: stack, width: nil, onLog: { onLog(stack) })
                    }
                }
                .padding(.vertical, 6)  // room for the card shadow
                .padding(.horizontal, horizontalMargin)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Spacing.cardGap) {
                        ForEach(stacks, id: \.persistentModelID) { stack in
                            StackCard(stack: stack, onLog: { onLog(stack) })
                        }
                    }
                    .padding(.vertical, 6)  // room for the card shadow
                }
                .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
            }
        }
    }
}

/// A stack in the sideways row: title (+ check when logged today), its nutrients' tiles, Log / Log again.
private struct StackCard: View {
    let stack: LogStack
    /// 176 pt in the sideways row; nil fills a tile.
    var width: CGFloat? = 176
    let onLog: () -> Void

    var body: some View {
        let done = StackLogging.isLoggedToday(stack)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(stack.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if done {
                        StackDoneBadge()
                    }
                }
                StackTiles(stack: stack)
            }
            // Cards in the row share the tallest one's height, with the button at the bottom.
            Spacer(minLength: 10)
            StackLogButton(stackName: stack.name, done: done, fullWidth: true, action: onLog)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: .infinity, alignment: .top)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StackAccessibility.label(for: stack, done: done))
    }
}

/// The one-stack layout: a full-width card with the title, tiles and count, and a Log pill on the right.
private struct SingleStackCard: View {
    let stack: LogStack
    let onLog: () -> Void

    var body: some View {
        let done = StackLogging.isLoggedToday(stack)
        let count = StackLogging.activeEntries(of: stack).count
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(stack.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if done {
                        StackDoneBadge()
                    }
                }
                // The count drops out rather than wrapping when "Log again" takes the room.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        StackTiles(stack: stack)
                        Text(count == 1 ? "1 nutrient" : "\(count) nutrients")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize()
                    }
                    StackTiles(stack: stack)
                }
            }
            Spacer(minLength: 8)
            StackLogButton(stackName: stack.name, done: done, fullWidth: false, action: onLog)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StackAccessibility.label(for: stack, done: done))
    }
}

/// The accessibility-size card: full width, the nutrients as text (· "logged 08:12" once logged today), and a
/// full-width Log / Log again.
private struct LargeTextStackCard: View {
    let stack: LogStack
    let onLog: () -> Void

    var body: some View {
        let done = StackLogging.isLoggedToday(stack)
        let loggedAt = done ? stack.lastLoggedAt?.formatted(date: .omitted, time: .shortened) : nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(stack.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                if done {
                    StackDoneBadge()
                }
            }
            Text(loggedAt.map { "\(StackLogging.summary(of: stack)) · logged \($0)" } ?? StackLogging.summary(of: stack))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            StackLogButton(stackName: stack.name, done: done, fullWidth: true, showsIcon: true, action: onLog)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StackAccessibility.label(for: stack, done: done))
    }
}

/// 24pt tiles for a stack's nutrients (radius 7 at that size), at most five plus "+2".
private struct StackTiles: View {
    let stack: LogStack

    var body: some View {
        let nutrients = StackLogging.activeEntries(of: stack).compactMap(\.nutrient)
        HStack(spacing: 6) {
            ForEach(nutrients.prefix(5), id: \.persistentModelID) { nutrient in
                NutrientIconTile(nutrient: nutrient, size: 24)
            }
            if nutrients.count > 5 {
                Text("+\(nutrients.count - 5)")
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityHidden(true)  // the card's label lists the nutrients
    }
}

/// Primary "Log", or ghost "Log again" once the stack was logged today.
private struct StackLogButton: View {
    let stackName: String
    let done: Bool
    let fullWidth: Bool
    /// "+ Log" (the full-width card's pill and the large-text cards) or "Log" (the 176pt cards).
    var showsIcon: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if done {
                    Text("Log again")
                } else {
                    Label("Log", systemImage: "plus")
                        .labelStyle(StackLogLabelStyle(showsIcon: showsIcon ?? !fullWidth))
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(done ? Theme.textPrimary : Theme.controlOnPrimary)
            .padding(.horizontal, fullWidth ? 0 : 18)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Theme.minTouchTarget)
            .background {
                if done {
                    Capsule().strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                } else {
                    Capsule().fill(Theme.controlPrimary)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // "Log Morning", as in the Stacks tab: on its own "Log" doesn't say which stack.
        .accessibilityLabel(done ? "Log \(stackName) again" : "Log \(stackName)")
    }
}

/// "Log" alone on the 176pt cards, "+ Log" on the full-width card's pill.
private struct StackLogLabelStyle: LabelStyle {
    let showsIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if showsIcon {
                configuration.icon
            }
            configuration.title
        }
    }
}

/// The 20pt green check by a stack's title when it was logged today (decorative: the label says "logged today").
/// Drawn, not an SF Symbol: a checkmark image was read as "Selected" even hidden (#203, as #77). The card's label
/// already ends "Logged today."
private struct StackDoneBadge: View {
    var body: some View {
        CheckmarkShape()
            .stroke(Theme.forest, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 9, height: 7)
            .frame(width: 20, height: 20)
            .background(Theme.green, in: Circle())
            .accessibilityHidden(true)
    }
}

enum StackAccessibility {
    /// "Morning: Vitamin D, Omega-3, Magnesium. Logged today."
    static func label(for stack: LogStack, done: Bool) -> String {
        "\(stack.name): \(StackLogging.summary(of: stack))." + (done ? " Logged today." : "")
    }
}

private struct StacksRowPreview: View {
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    var onlyFirst = false
    var layout: StacksRow.Layout = .row
    /// The large-screen layouts at the width they get there (LAYOUT.md): tiles across an 11-inch iPad's 786 pt,
    /// the list in the 360 pt side column.
    var width: CGFloat? = nil

    var body: some View {
        ScrollView {
            StacksRow(stacks: onlyFirst ? Array(stacks.prefix(1)) : stacks, layout: layout,
                      horizontalMargin: width == nil ? Theme.Spacing.screenMargin : 0, onLog: { _ in }, onEdit: {})
                .frame(width: width)
                .padding(.vertical)
        }
        .background(Theme.surfaceGround)
    }
}

#Preview("Stacks") {
    StacksRowPreview()
        .modelContainer(previewContainer)
}

#Preview("One stack") {
    StacksRowPreview(onlyFirst: true)
        .modelContainer(previewContainer)
}

#Preview("Accessibility 3") {
    StacksRowPreview()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}

// The sample data has two stacks, so the tiles fill two of three slots. A single stack keeps the one full-width card
// in every layout, as on iPhone, rather than a lone tile.
#Preview("Tiles", traits: .fixedLayout(width: 834, height: 400)) {
    StacksRowPreview(layout: .tiles, width: 786)
        .modelContainer(previewContainer)
}

#Preview("Tiles, one stack", traits: .fixedLayout(width: 834, height: 400)) {
    StacksRowPreview(onlyFirst: true, layout: .tiles, width: 786)
        .modelContainer(previewContainer)
}

#Preview("Side column list", traits: .fixedLayout(width: 420, height: 400)) {
    StacksRowPreview(layout: .list, width: 360)
        .modelContainer(previewContainer)
}
