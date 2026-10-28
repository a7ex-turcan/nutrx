import SwiftUI

/// The recap card on Today (nutrx Pro, docs/pro/design/5-weekly-recap: today): "Your week" from Sunday evening through
/// Monday, "Your October" on the 1st and 2nd, or "Your 2026" from 1 to 7 January (#136). A small ring of goals met,
/// "31 of 42 goals · Vitamin D steadiest", and a close button that hides it for that period.
struct RecapTodayCard: View {
    let title: String
    /// Markdown: the first number bold.
    let line: String
    let fraction: Double
    let openHint: String
    let hideLabel: String
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(week recap: WeeklyRecap, onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.init(title: "Your week", line: RecapText(recap).todayLine,
                  fraction: recap.goalsCounted > 0 ? Double(recap.goalsMet) / Double(recap.goalsCounted) : 0,
                  openHint: "Opens the weekly recap", hideLabel: "Hide this week's recap",
                  onOpen: onOpen, onDismiss: onDismiss)
    }

    init(month recap: MonthlyRecap, onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        let text = MonthlyRecapText(recap)
        self.init(title: "Your \(text.monthName)", line: text.todayLine, fraction: recap.rate ?? 0,
                  openHint: "Opens the monthly recap", hideLabel: "Hide \(text.monthName)'s recap",
                  onOpen: onOpen, onDismiss: onDismiss)
    }

    init(year recap: YearlyRecap, onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        let text = YearlyRecapText(recap)
        self.init(title: "Your \(text.yearName)", line: text.todayLine, fraction: recap.rate ?? 0,
                  openHint: "Opens the yearly recap", hideLabel: "Hide \(text.yearName)'s recap",
                  onOpen: onOpen, onDismiss: onDismiss)
    }

    private init(title: String, line: String, fraction: Double, openHint: String, hideLabel: String,
                 onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.title = title
        self.line = line
        self.fraction = fraction
        self.openHint = openHint
        self.hideLabel = hideLabel
        self.onOpen = onOpen
        self.onDismiss = onDismiss
    }

    var body: some View {
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
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text((try? AttributedString(markdown: line)) ?? "")
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
            .accessibilityHint(openHint)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hideLabel)
        }
        .padding(.leading, Theme.Spacing.cardPadding + 2)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .cardStyle()
    }
}
