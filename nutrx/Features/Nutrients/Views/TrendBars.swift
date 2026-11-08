import SwiftUI

/// One side of a trend comparison in a nutrient's analytics: its label, a bar filled to `fraction`, and the value.
/// "With Apple Health" and "With how you feel" (#133) both use it, so the two cards stay alike.
struct TrendComparisonBar: View {
    let label: String
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 104, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceChip)
                    Capsule().fill(color).frame(width: max(8, geometry.size.width * fraction))
                }
            }
            .frame(height: 12)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 64, alignment: .trailing)
        }
    }
}

/// The days gathered so far toward a trend, one segment a day: Health's paired days, How you feel's answered ones.
struct TrendProgressBar: View {
    let total: Int
    let filled: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? color : Theme.surfaceChip)
                    .frame(height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}
