import SwiftUI

/// How much width a view actually gets (docs/design/large-screens/LAYOUT.md, #151): the iPhone layout under 704 pt,
/// two columns and split views from 704, more air from 1000. Measured from the window (or a split pane), never from
/// the device or `horizontalSizeClass`, so a narrow iPad multitasking window or the folded Duo stays compact.
nonisolated enum WidthClass: Equatable, Sendable {
    case compact, regular, wide

    /// Two card columns need 2 × 320 + 16 pt of content plus 24 pt margins: 704.
    static let regularMinimum: CGFloat = 704
    static let wideMinimum: CGFloat = 1000

    init(width: CGFloat) {
        if width >= Self.wideMinimum {
            self = .wide
        } else if width >= Self.regularMinimum {
            self = .regular
        } else {
            self = .compact
        }
    }

    /// The narrowest margin beside centred content: 24 pt, 40 on wide.
    var minimumMargin: CGFloat { self == .wide ? 40 : 24 }
}

extension EnvironmentValues {
    /// The window's width class, set at the root by `measuresWidthClass()`. Sheets inherit it from the screen that
    /// presents them.
    @Entry var widthClass: WidthClass = .compact
}

/// Pages that aren't redesigned for large screens keep their content in one centred column (LAYOUT.md, "Everything
/// else"). Pure, tested in `WidthClassTests`.
nonisolated enum ReadableColumn {
    static let maxWidth: CGFloat = 640

    /// The padding to add on each side of a page `width` wide whose content already has `ownMargin` of its own, so
    /// the content is at most 640 pt wide with at least the width class's margin. 0 on compact widths: the iPhone
    /// layout doesn't change.
    static func extraInset(width: CGFloat, ownMargin: CGFloat) -> CGFloat {
        let widthClass = WidthClass(width: width)
        guard widthClass != .compact else { return 0 }
        let margin = max(widthClass.minimumMargin, (width - maxWidth) / 2)
        return max(0, margin - ownMargin)
    }
}

extension View {
    /// Measures the width this view gets and passes its `WidthClass` down the environment. Apply at the root.
    func measuresWidthClass() -> some View {
        modifier(WidthClassReader())
    }

    /// Keeps the content in a centred column at most 640 pt wide (24 pt margins at least, 40 on wide). It pads the
    /// safe area, so a `List` or `ScrollView` still scrolls and draws its background across the whole window, and
    /// anything that ignores the safe area (a full-bleed background) still spans it. Nothing changes on compact
    /// widths. `ownMargin` is the horizontal margin the content already has.
    func readableColumn(ownMargin: CGFloat = Theme.Spacing.screenMargin) -> some View {
        modifier(ReadableColumnModifier(ownMargin: ownMargin))
    }
}

private struct WidthClassReader: ViewModifier {
    @State private var widthClass: WidthClass = .compact

    func body(content: Content) -> some View {
        content
            .environment(\.widthClass, widthClass)
            .onGeometryChange(for: WidthClass.self) { WidthClass(width: $0.size.width) } action: { widthClass = $0 }
    }
}

private struct ReadableColumnModifier: ViewModifier {
    let ownMargin: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, ReadableColumn.extraInset(width: width, ownMargin: ownMargin))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
