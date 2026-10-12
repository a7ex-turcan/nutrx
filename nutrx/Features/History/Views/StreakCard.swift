import SwiftUI

/// History's forest streak card (DESIGN.md §5.4): flame, "10 days", "Current streak · every goal met", and the
/// best streak beside a divider.
struct StreakCard: View {
    let current: Int
    let best: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the best streak moves under the current one.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(spacing: 16))

        layout {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.greenSoft)
                    .frame(width: 52, height: 52)
                    .background(Theme.onForestPrimary.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(HistoryText.days(current))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.onForestPrimary)
                    Text("Current streak · every goal met")
                        .font(.subheadline)
                        .foregroundStyle(Theme.onForestSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Rectangle()
                    .fill(Theme.onForestPrimary.opacity(0.15))
                    .frame(width: 1, height: 44)
                    .accessibilityHidden(true)
            }

            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 0) {
                Text("\(best)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.onForestPrimary)
                Text("Best")
                    .font(.subheadline)
                    .foregroundStyle(Theme.onForestSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best streak, \(HistoryText.days(best))")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(fill: Theme.forest, cornerRadius: Theme.Radius.hero)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    VStack(spacing: 16) {
        StreakCard(current: 10, best: 31)
        StreakCard(current: 1, best: 1)
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.surfaceGround)
}

#Preview("Dark") {
    StreakCard(current: 10, best: 31)
        .padding()
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
