import SwiftUI

/// A recap's fact cards in two columns (one, without icons, at accessibility sizes): steadiest, slipped, the day you
/// tend to miss, the streak or best run, and the month's comparison; the year's best month, days logged and
/// beginnings (#136).
struct RecapFactGrid: View {
    let cards: [RecapText.Card]
    /// For the steadiest and slipped cards' icon tiles.
    let nutrientsByID: [UUID: Nutrient]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: Theme.Spacing.cardGap), GridItem(.flexible())]
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.cardGap) {
            ForEach(cards, id: \.label) { card in
                factCard(card)
            }
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
