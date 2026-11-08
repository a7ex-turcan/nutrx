import SwiftData
import SwiftUI

/// "With how you feel" in a nutrient's analytics (nutrx Pro, #133, docs/pro/HOW-YOU-FEEL.md §3), below "With Apple
/// Health": one or two findings with a two-bar comparison and the days behind them, or the state. Free users with
/// answers get the teaser with the PRO chip; with How you feel off and no answers, anyone gets where to turn it on.
struct FeelingTrendsCard: View {
    let nutrient: Nutrient
    let state: FeelingTrends.State?
    /// How you feel is on, or has answers.
    let isInUse: Bool

    @Environment(ProAccess.self) private var proAccess: ProAccess?
    private let padding: CGFloat = 18

    private var text: FeelingTrendText {
        FeelingTrendText(nutrientName: nutrient.name, unit: nutrient.unit, goal: AnalyticsGoal(nutrient: nutrient))
    }

    private var isPro: Bool { proAccess?.isPro ?? false }

    var body: some View {
        // In use with every question removed, there's nothing to read.
        if ProAccess.isStoreVisible, !isInUse || state != nil {
            VStack(alignment: .leading, spacing: 14) {
                header
                content
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "face.smiling")
                .font(.headline)
                .foregroundStyle(Theme.SettingsTile.pink)
                .accessibilityHidden(true)
            Text(FeelingTrendText.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if isInUse, !isPro {
                ProBadge()
            } else if isPro, case .findings = state {
                Text(FeelingTrendText.period)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isInUse {
            Text(FeelingTrendText.turnOn)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        } else if !isPro {
            Text(FeelingTrendText.teaser(device: UIDevice.current.model))
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            ProGatedButton(action: {}) { _ in
                Text("Learn about nutrx Pro")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            switch state {
            case nil:
                EmptyView()
            case .notEnoughData(let question, let paired):
                notEnough(question: question, paired: paired)
            case .noPattern(let checked):
                Text(text.noPattern).font(.body).foregroundStyle(Theme.textPrimary)
                Text(HealthText.checked(days: checked)).font(.footnote).foregroundStyle(Theme.textSecondary)
            case .findings(let findings):
                ForEach(Array(findings.enumerated()), id: \.offset) { index, finding in
                    if index > 0 { Divider().overlay(Theme.lineHairline) }
                    findingView(finding)
                }
                Text(FeelingTrendText.footer(device: UIDevice.current.model))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
            }
        }
    }

    private func notEnough(question: String, paired: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FeelingTrendText.notEnoughData).font(.body).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                ForEach(0..<FeelingTrends.minimumPairedDays, id: \.self) { index in
                    Capsule()
                        .fill(index < paired ? Theme.SettingsTile.pink : Theme.surfaceChip)
                        .frame(height: 10)
                }
            }
            .accessibilityHidden(true)
            Text(FeelingTrendText.progress(question: question, pairedDays: paired))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func findingView(_ finding: FeelingTrends.Finding) -> some View {
        let (firstLabel, secondLabel) = text.labels(finding)
        // A scale's bars out of 5; yes / no as the share of days.
        let top = finding.question.kind == .scale ? 5.0 : 1.0
        return VStack(alignment: .leading, spacing: 10) {
            Text(text.sentence(finding))
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            bar(firstLabel, value: text.value(finding.first, of: finding),
                fraction: finding.first.average / top, color: nutrient.tint.color)
            bar(secondLabel, value: text.value(finding.second, of: finding),
                fraction: finding.second.average / top, color: nutrient.tint.color.opacity(0.5))
            Text(text.basis(finding))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
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

// MARK: - Previews

// Debug only: `ProAccess.previewPro()` doesn't exist in Release builds.
#if DEBUG
private struct FeelingTrendsCardPreview: View {
    let state: FeelingTrends.State?
    var isInUse = true
    var body: some View {
        let nutrient = Nutrient(name: "Magnesium", unit: "mg", step: 200, dailyTarget: 400, sortOrder: 0)
        ScrollView {
            FeelingTrendsCard(nutrient: nutrient, state: state, isInUse: isInUse)
                .padding()
        }
        .background(Theme.surfaceGround)
        .environment(ProAccess.previewPro())
        .modelContainer(previewContainer)
    }
}

private let previewFindings = FeelingTrends.State.findings([
    .init(question: .init(title: "Sleep last night", kind: .scale, preset: .sleep, aboutNightBefore: true, answers: [:]),
          first: .init(average: 4.4, days: 17, yesDays: 0), second: .init(average: 2.5, days: 4, yesDays: 0),
          threshold: nil),
    .init(question: .init(title: "Headache", kind: .yesNo, preset: .headache, aboutNightBefore: false, answers: [:]),
          first: .init(average: 2.0 / 15, days: 15, yesDays: 2), second: .init(average: 3.0 / 6, days: 6, yesDays: 3),
          threshold: nil),
])

#Preview("Findings") { FeelingTrendsCardPreview(state: previewFindings) }
#Preview("Findings, dark") { FeelingTrendsCardPreview(state: previewFindings).preferredColorScheme(.dark) }
#Preview("Not enough data") { FeelingTrendsCardPreview(state: .notEnoughData(question: "Energy", pairedDays: 9)) }
#Preview("Not in use") { FeelingTrendsCardPreview(state: nil, isInUse: false) }
#endif
