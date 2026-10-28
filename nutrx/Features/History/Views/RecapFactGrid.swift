import SwiftUI

/// A recap's fact cards in two columns, a last one on its own across both (one column, without icons, at
/// accessibility sizes): steadiest, slipped, the day you tend to miss, the streak or best run, and the month's
/// comparison; the year's best month, days logged and beginnings (#136).
struct RecapFactGrid: View {
    let cards: [RecapText.Card]
    /// For the steadiest and slipped cards' icon tiles.
    let nutrientsByID: [UUID: Nutrient]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let twoColumns = !dynamicTypeSize.isAccessibilitySize
        let columns = twoColumns
            ? [GridItem(.flexible(), spacing: Theme.Spacing.cardGap), GridItem(.flexible())]
            : [GridItem(.flexible())]
        // A last card alone on its row takes the width rather than leaving half of it empty (#317).
        let lone = twoColumns && cards.count % 2 == 1 ? cards.last : nil
        let paired = lone == nil ? cards : Array(cards.dropLast())
        VStack(spacing: Theme.Spacing.cardGap) {
            if !paired.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.cardGap) {
                    ForEach(paired, id: \.label) { card in
                        factCard(card)
                    }
                }
            }
            // Its natural height: `factCard` fills the height it's offered, for equal heights in a grid row.
            if let lone { factCard(lone).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private func factCard(_ card: RecapText.Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                if !dynamicTypeSize.isAccessibilitySize { cardIcon(card) }
                Text(card.value)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Text(card.detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cardIcon(_ card: RecapText.Card) -> some View {
        switch card.kind {
        case .steadiest, .slipped:
            if let id = card.nutrientID, let nutrient = nutrientsByID[id] {
                NutrientIconTile(nutrient: nutrient, size: 32)
            }
        case .started:
            if let id = card.nutrientID, let nutrient = nutrientsByID[id] {
                NutrientIconTile(nutrient: nutrient, size: 32)
            } else {
                NutrientIconTile(tint: .green, symbolName: "leaf", size: 32)
            }
        case .bestMonth:
            NutrientIconTile(tint: .amber, symbolName: "trophy", size: 32)
        case .daysLogged:
            NutrientIconTile(tint: .teal, symbolName: "square.and.pencil", size: 32)
        case .weekday:
            NutrientIconTile(tint: .indigo, symbolName: "calendar", size: 32)
        case .streak:
            NutrientIconTile(tint: .coral, symbolName: "flame", size: 32)
        case .comparison:
            NutrientIconTile(tint: .green, symbolName: "chart.line.uptrend.xyaxis", size: 32)
        }
    }
}

#if DEBUG
#Preview("Light") {
    RecapFactGrid(cards: YearlyRecapText(RecapPreviewSample.year).cards + MonthlyRecapText(RecapPreviewSample.month).cards,
                  nutrientsByID: [:])
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    RecapFactGrid(cards: MonthlyRecapText(RecapPreviewSample.month).cards, nutrientsByID: [:])
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
#endif
