import SwiftUI

/// "Your week" on Today from Sunday evening through Monday (nutrx Pro, docs/pro/design/5-weekly-recap: today): a
/// small ring of goals met, "31 of 42 goals · Vitamin D steadiest", and a close button that hides it for that week.
struct RecapTodayCard: View {
    let recap: WeeklyRecap
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let fraction = recap.goalsCounted > 0 ? Double(recap.goalsMet) / Double(recap.goalsCounted) : 0
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    // The words get the room at accessibility sizes.
                    if !dynamicTypeSize.isAccessibilitySize {
                        ZStack {
                            Circle().stroke(Theme.surfaceChip, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: fraction)
                                .stroke(Theme.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your week")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text((try? AttributedString(markdown: RecapText(recap).todayLine)) ?? "")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the weekly recap")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide this week's recap")
        }
        .padding(.leading, Theme.Spacing.cardPadding + 2)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .cardStyle()
    }
}
