import SwiftUI

/// Today's Apple Health card (#102), for a Pro user with Health connected: while insights are gathering, how close the
/// nearest nutrient is ("9 of 14 days"); once one is ready, a pointer to it. "See where" opens that nutrient's
/// analytics at its With Apple Health card; ✕ hides it (each state once).
struct HealthInsightsTodayCard: View {
    let status: HealthInsights.Status
    let onSeeWhere: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let title = HealthText.todayTitle(status), let body = HealthText.todayBody(status) {
            HStack(alignment: .top, spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize {
                    NutrientIconTile(tint: .coral, symbolName: "heart.fill", size: 40)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("See where", action: onSeeWhere)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.controlPrimary)
                        .buttonStyle(.plain)
                        .frame(minHeight: Theme.minTouchTarget)
                        .accessibilityHint("Opens the nutrient's analytics, where Apple Health insights appear")
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide")
            }
            .padding(.leading, Theme.Spacing.cardPadding + 2)
            .padding(.trailing, 4)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .cardStyle()
        }
    }
}

#Preview("Gathering") {
    HealthInsightsTodayCard(status: .gathering(nutrientID: UUID(), nutrientName: "Vitamin D", pairedDays: 9),
                            onSeeWhere: {}, onDismiss: {})
        .padding()
        .background(Theme.surfaceGround)
}
