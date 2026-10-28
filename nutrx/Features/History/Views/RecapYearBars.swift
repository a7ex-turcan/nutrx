import SwiftUI

/// The year's months as twelve small bars of their goals-met rate (#136, docs/pro/RECAPS.md §3): the best month in
/// green, the others paler, a month with nothing counted as just its track. One VoiceOver element that reads each
/// month's rate.
struct RecapYearBars: View {
    let recap: YearlyRecap

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let barHeight: CGFloat = 96

    var body: some View {
        let text = YearlyRecapText(recap)
        VStack(alignment: .leading, spacing: 10) {
            Text("Month by month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(recap.months, id: \.monthStart) { month in
                    VStack(spacing: 6) {
                        bar(month)
                        Text(text.barLetter(month))
                            .font(.caption2.weight(month == recap.bestMonth ? .bold : .semibold))
                            .foregroundStyle(month == recap.bestMonth ? Theme.textPrimary : Theme.textSecondary)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // twelve columns
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Month by month, goals met")
        .accessibilityValue(text.barsAccessibilityValue)
    }

    private func bar(_ month: YearlyRecap.Month) -> some View {
        let isBest = month == recap.bestMonth
        return ZStack(alignment: .bottom) {
            Capsule().fill(Theme.surfaceChip)
            if let rate = month.rate, rate > 0 {
                // At least the bar's width tall, so a low month still shows as a dot of colour.
                Capsule()
                    .fill(isBest ? Theme.green : Theme.green.opacity(0.45))
                    .frame(height: max(Self.barHeight * rate, 8))
            }
        }
        .frame(height: Self.barHeight)
        .frame(maxWidth: 14)
    }
}

#Preview("Light") {
    RecapYearBars(recap: RecapPreviewSample.year)
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    RecapYearBars(recap: RecapPreviewSample.year)
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
