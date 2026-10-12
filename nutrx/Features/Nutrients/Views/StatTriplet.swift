import SwiftUI

/// Three stats side by side — Hit rate / Daily avg / Best day (DESIGN.md §4.8). Stacks at accessibility sizes.
struct StatTriplet: View {
    let stats: [AnalyticsStat]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))

        layout {
            ForEach(stats) { stat in
                column(stat)
            }
        }
    }

    private func column(_ stat: AnalyticsStat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            value(stat)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(stat.caption)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func value(_ stat: AnalyticsStat) -> Text {
        let number = Text(stat.value).foregroundStyle(Theme.textPrimary)
        guard let suffix = stat.suffix else { return number }
        let small = Text(suffix)
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        return Text("\(number)\(small)")
    }
}

#Preview("Light") {
    StatTriplet(stats: [
        AnalyticsStat(label: "Hit rate", value: "83", suffix: "%", caption: "5 of 6 days"),
        AnalyticsStat(label: "Daily avg", value: "3,830", caption: "IU"),
        AnalyticsStat(label: "Best day", value: "5,000", caption: "Friday"),
    ])
    .padding(18)
    .cardStyle()
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.surfaceGround)
}
