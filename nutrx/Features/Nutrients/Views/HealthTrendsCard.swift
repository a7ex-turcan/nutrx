import SwiftUI

/// "With Apple Health" in a nutrient's analytics (nutrx Pro, docs/pro/design/6-health-trends): one or two findings
/// with a two-bar comparison and the days behind them, or the state (connect, not enough days, no pattern, no Health
/// data). Free users get a quiet teaser with the PRO chip.
struct HealthTrendsCard: View {
    let nutrient: Nutrient
    let state: HealthTrends.State?
    let isConnected: Bool
    let onConnect: () -> Void

    @Environment(ProAccess.self) private var proAccess: ProAccess?
    private let padding: CGFloat = 18

    private var text: HealthText {
        HealthText(nutrientName: nutrient.name, unit: nutrient.unit, goal: AnalyticsGoal(nutrient: nutrient))
    }

    var body: some View {
        if ProAccess.isStoreVisible, HealthReader.isAvailable {
            VStack(alignment: .leading, spacing: 14) {
                header
                content
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private var isPro: Bool { proAccess?.isPro ?? false }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.headline)
                .foregroundStyle(NutrientTint.coral.color)
                .accessibilityHidden(true)
            Text(HealthText.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !isPro {
                ProBadge()
            } else if case .findings = state {
                Text(HealthText.period)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isPro {
            Text(HealthText.teaser(device: UIDevice.current.model))
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            ProGatedButton(action: {}) { _ in
                Text("Learn about nutrx Pro")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else if !isConnected {
            Text("See how \(nutrient.name) lines up with your sleep and workouts. Read on this \(UIDevice.current.model) only.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Button(action: onConnect) {
                Text("Connect Apple Health")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            switch state {
            case nil:
                ProgressView().frame(maxWidth: .infinity, minHeight: 60)
            case .noHealthData:
                Text(HealthText.noHealthData).font(.body).foregroundStyle(Theme.textPrimary)
            case .notEnoughData(let paired):
                notEnough(paired)
            case .noPattern(let checked):
                Text(text.noPattern).font(.body).foregroundStyle(Theme.textPrimary)
                Text(HealthText.checked(days: checked)).font(.footnote).foregroundStyle(Theme.textSecondary)
            case .findings(let findings):
                ForEach(Array(findings.enumerated()), id: \.offset) { index, finding in
                    if index > 0 { Divider().overlay(Theme.lineHairline) }
                    findingView(finding)
                }
                Text(HealthText.footer(device: UIDevice.current.model))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
            }
        }
    }

    private func notEnough(_ paired: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HealthText.notEnoughData).font(.body).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                ForEach(0..<HealthTrends.minimumPairedDays, id: \.self) { index in
                    Capsule()
                        .fill(index < paired ? NutrientTint.coral.color : Theme.surfaceChip)
                        .frame(height: 10)
                }
            }
            .accessibilityHidden(true)
            Text(HealthText.progress(pairedDays: paired))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func findingView(_ finding: HealthTrends.Finding) -> some View {
        let (firstLabel, secondLabel) = text.labels(finding)
        let top = max(finding.first.average, finding.second.average, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text(text.sentence(finding))
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            bar(firstLabel, value: text.value(finding.first, of: finding),
                fraction: finding.first.average / top, color: nutrient.tint.color)
            // Half the tint: at a third it all but vanished into the track in dark mode.
            bar(secondLabel, value: text.value(finding.second, of: finding),
                fraction: finding.second.average / top, color: nutrient.tint.color.opacity(0.5))
            Text(text.basis(finding))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        // One sentence for VoiceOver, without the stray ".," a combined element reads between the parts.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(text.sentence(finding)) \(firstLabel): \(text.value(finding.first, of: finding)); "
                + "\(secondLabel): \(text.value(finding.second, of: finding)). \(text.basis(finding))")
    }

    private func bar(_ label: String, value: String, fraction: Double, color: Color) -> some View {
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
