import SwiftUI

/// Grid of 44pt symbol tiles; the selected one takes the nutrient's tint tile colours (DESIGN.md §4.10).
struct SymbolPicker: View {
    @Binding var selection: String
    let tint: NutrientTint

    /// The picker set from DESIGN.md §3, with VoiceOver names.
    static let choices: [(symbol: String, name: String)] = [
        ("pills", "Pills"), ("sun.max", "Sun"), ("moon", "Moon"), ("drop", "Drop"),
        ("fish", "Fish"), ("leaf", "Leaf"), ("carrot", "Carrot"), ("flame", "Flame"),
        ("bolt", "Bolt"), ("heart", "Heart"), ("dumbbell", "Dumbbell"), ("cup.and.saucer", "Cup"),
        ("waterbottle", "Water bottle"), ("cross.vial", "Vial"), ("brain.head.profile", "Brain"),
        ("figure.run", "Runner"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Self.choices, id: \.symbol) { choice in
                tile(choice.symbol, name: choice.name)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Icon")
    }

    private func tile(_ symbol: String, name: String) -> some View {
        let isSelected = symbol == selection
        return Button {
            selection = symbol
        } label: {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .fontWeight(.regular)
                .frame(width: 22, height: 22)
                .foregroundStyle(isSelected ? tint.tileGlyph : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                .background(isSelected ? tint.tileBackground : Theme.surfaceGround,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Light") {
    @Previewable @State var symbol = "waterbottle"
    SymbolPicker(selection: $symbol, tint: .teal)
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    @Previewable @State var symbol = "sun.max"
    SymbolPicker(selection: $symbol, tint: .amber)
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
