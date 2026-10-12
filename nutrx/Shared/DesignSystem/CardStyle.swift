import SwiftUI

/// Card surface from DESIGN.md §1.4: filled rounded rectangle with a subtle forest shadow in light mode,
/// and a 1pt white @ 5% inner stroke instead of a shadow in dark mode.
struct CardStyle: ViewModifier {
    var fill: Color = Theme.surfaceCard
    var cornerRadius: CGFloat = Theme.Radius.card

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(fill, in: shape)
            .overlay {
                if colorScheme == .dark {
                    shape.strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                }
            }
            .shadow(color: colorScheme == .dark ? .clear : Theme.forest.opacity(0.10), radius: 10, y: 6)
    }
}

extension View {
    func cardStyle(fill: Color = Theme.surfaceCard, cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardStyle(fill: fill, cornerRadius: cornerRadius))
    }
}
