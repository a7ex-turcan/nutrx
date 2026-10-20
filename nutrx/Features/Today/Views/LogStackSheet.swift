import SwiftUI
import SwiftData

/// Logs a stack from Today (docs/pro/design/1-stacks-export: log-stack, log-stack-done). Each entry shows its ring
/// and today's total with an amount stepper; changes apply to this time only. After logging, the rings show the new
/// totals, each row its "+2,000 IU", and a strip "Logged 3 nutrients at 08:12" with Undo and Done.
struct LogStackSheet: View {
    let stack: LogStack
    /// Today's total for a nutrient, from Today's view model.
    let totalFor: (Nutrient) -> Double
    let onLog: ([PersistentIdentifier: Double]) -> StackLogging.Logged
    let onUndo: (StackLogging.Logged) -> Void
    let onEditStack: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Amounts changed for this time only, by entry.
    @State private var amounts: [PersistentIdentifier: Double] = [:]
    /// Set once logged: what was logged and the amount per entry, for the done state and Undo.
    @State private var logged: StackLogging.Logged?
    @State private var loggedAmounts: [PersistentIdentifier: Double] = [:]
    /// Full height from the start when the rows don't fit at half height (`rowsAtHalfHeight`).
    @State private var detent: PresentationDetent

    init(stack: LogStack, totalFor: @escaping (Nutrient) -> Double,
         onLog: @escaping ([PersistentIdentifier: Double]) -> StackLogging.Logged,
         onUndo: @escaping (StackLogging.Logged) -> Void, onEditStack: @escaping () -> Void) {
        self.stack = stack
        self.totalFor = totalFor
        self.onLog = onLog
        self.onUndo = onUndo
        self.onEditStack = onEditStack
        _detent = State(initialValue: StackLogging.activeEntries(of: stack).count > Self.rowsAtHalfHeight ? .large : .medium)
    }

    /// Whether every row puts its stepper under the name and total (from xLarge, #97) rather than beside them.
    private var rowsAreStacked: Bool { dynamicTypeSize >= .xLarge }

    private var entries: [LogStackEntry] { StackLogging.activeEntries(of: stack) }

    /// Rows shown at the medium detent before the sheet opens full height instead.
    static let rowsAtHalfHeight = 3

    private func amount(for entry: LogStackEntry) -> Double {
        amounts[entry.persistentModelID] ?? entry.amount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        if index > 0 {
                            Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        }
                        row(entry)
                    }
                }
                .cardStyle()

                // At accessibility sizes the sheet is full height and the footer scrolls with the rows.
                if dynamicTypeSize.isAccessibilitySize {
                    footer
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Rows scrolled up at half height were drawn above the sheet's top edge.
        .clipped()
        // Pinned, so Log (or Undo / Done) is on screen at half height whatever the phone and text size; the rows
        // scroll above it.
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                footer
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Theme.surfaceGround)
            }
        }
        .background(Theme.surfaceGround)
        // At accessibility sizes half a screen holds only the header and one row, so it opens full height. With
        // more than three rows it opens full height too, so they're all in view (it can still be dragged down).
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large],
                             selection: dynamicTypeSize.isAccessibilitySize ? .constant(.large) : $detent)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var footer: some View {
        if let logged {
            doneFooter(logged)
        } else {
            logFooter
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stack.name)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(logged == nil ? "\(countText) · amounts for this time" : "Logged today")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .background(Theme.surfaceChip, in: Circle())
            }
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the glyph stays inside its 44pt circle
            .accessibilityLabel("Close")
        }
    }

    /// One line per word, so a word shrinks a little rather than breaking ("Magne-sium"). A word too long to fit even
    /// shrunk ("Phosphatidylserine") gets one more line: broken, it's still readable; cut off, it isn't.
    static func nameLineLimit(_ name: String) -> Int {
        let words = name.split(separator: " ")
        let longest = words.map(\.count).max() ?? 0
        return max(words.count, 1) + (longest > 12 ? 1 : 0)
    }

    private var countText: String {
        entries.count == 1 ? "1 nutrient" : "\(entries.count) nutrients"
    }

    // MARK: - Rows

    private func row(_ entry: LogStackEntry) -> some View {
        let nutrient = entry.nutrient!  // active entries always have one
        let progress = GoalProgress(nutrient: nutrient, current: max(0, totalFor(nutrient)))
        let summary = HStack(spacing: 12) {
            ProgressRing(nutrient: nutrient, progress: progress)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(Self.nameLineLimit(nutrient.name))
                    .minimumScaleFactor(0.7)
                totalLine(progress)
            }
            .accessibilityElement(children: .combine)
        }
        return Group {
            // From xLarge the amount goes under the name in every row, so neither is broken mid-word: beside the
            // stepper, names broke from xLarge on an iPhone 17e (#97). One threshold for the whole sheet, never row by row.
            if rowsAreStacked {
                VStack(alignment: .leading, spacing: 10) {
                    summary
                    trailing(entry, nutrient: nutrient)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    summary
                    // No extra minimum: the stack's spacing keeps them apart, and the total needs every point (#97).
                    Spacer(minLength: 0)
                    trailing(entry, nutrient: nutrient)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 12)
    }

    /// "2,000 / 4,000 IU" (with "· Done" once logged and met). Beside the stepper it stays on one line: without the
    /// unit, which the stepper shows, when the whole doesn't fit, rather than wrapping at the slash (#97). Stacked
    /// rows have the width and may wrap.
    @ViewBuilder
    private func totalLine(_ progress: GoalProgress) -> some View {
        let done = logged != nil && progress.countsAsMet ? " · Done" : ""
        let full = "\(progress.currentText) \(progress.goalText)\(done)"
        if rowsAreStacked {
            totalText(full)
        } else {
            ViewThatFits(in: .horizontal) {
                totalText(full).lineLimit(1)
                totalText("\(progress.currentText) \(progress.goalTextWithoutUnit)\(done)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(full)
            }
        }
    }

    private func totalText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
    }

    /// The amount stepper before logging; the logged amount ("+2,000 IU", green) after.
    @ViewBuilder
    private func trailing(_ entry: LogStackEntry, nutrient: Nutrient) -> some View {
        if logged != nil {
            let loggedAmount = loggedAmounts[entry.persistentModelID] ?? 0
            let unitSuffix = nutrient.unit.isEmpty ? "" : " \(nutrient.unit)"
            Text(loggedAmount > 0 ? "+\(loggedAmount.formattedAmount())\(unitSuffix)" : "—")
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(loggedAmount > 0 ? Theme.textGreenInk : Theme.textSecondary)
                .fixedSize()
        } else {
            StackAmountStepper(amount: amount(for: entry), step: nutrient.step, unit: nutrient.unit,
                               nutrientName: nutrient.name) {
                amounts[entry.persistentModelID] = $0
            }
        }
    }

    // MARK: - Footers

    private var logFooter: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The note and a real Edit stack button (an inline link would only be reachable through VoiceOver's
            // Links rotor): on one line when they fit, the button under the note when they don't.
            let note = Text("Changes here apply to this time only.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            // The taps reach 12pt beyond the text (closer to 44pt) without moving it; the Log button below wins any
            // overlap.
            let editButton = Button(action: editStack) {
                Text("Edit stack")
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .padding(.vertical, -12)
                    .padding(.horizontal, -8)
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.controlPrimary)
            .buttonStyle(.plain)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    note.fixedSize()
                    editButton.fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    note
                    editButton
                }
            }

            Button {
                logNow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .fontWeight(.bold)
                        .foregroundStyle(colorScheme == .dark ? Theme.controlOnPrimary : Theme.greenSoft)
                    Text("Log \(countText)")
                }
                .font(.headline)
                .foregroundStyle(Theme.controlOnPrimary)
                .padding(.vertical, 12)  // room around the label once it wraps at large text sizes
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.controlPrimary,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(entries.isEmpty)
        }
    }

    private func doneFooter(_ logged: StackLogging.Logged) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.forest)
                    .frame(width: 28, height: 28)
                    .background(Theme.green, in: Circle())
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the glyph stays inside its 28pt circle
                    .accessibilityHidden(true)
                Text("Logged \(logged.records.count == 1 ? "1 nutrient" : "\(logged.records.count) nutrients") at \(logged.date.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textGreenInk)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.green.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                Button {
                    undo(logged)
                } label: {
                    Text("Undo")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(Theme.controlOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.controlPrimary,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func editStack() {
        dismiss()
        onEditStack()
    }

    private func logNow() {
        let snapshot = Dictionary(uniqueKeysWithValues: entries.map { ($0.persistentModelID, amount(for: $0)) })
        let result = onLog(amounts)
        withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.35))) {
            loggedAmounts = snapshot
            logged = result
        }
    }

    private func undo(_ logged: StackLogging.Logged) {
        Haptics.deleted()
        onUndo(logged)
        withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
            self.logged = nil
            loggedAmounts = [:]
        }
    }
}

// MARK: - Previews

private struct LogStackSheetPreview: View {
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    var firstName: String?

    // Rendered inline: preview snapshots don't capture presented sheets.
    var body: some View {
        if let stack = stacks.first {
            let _ = firstName.map { StackLogging.activeEntries(of: stack).first?.nutrient?.name = $0 }
            LogStackSheet(
                stack: stack,
                totalFor: { nutrient in (nutrient.intakeRecords ?? []).filter { Calendar.current.isDateInToday($0.date) }
                    .reduce(0) { $0 + $1.amount } },
                onLog: { _ in StackLogging.Logged(records: [], previousLastLoggedAt: nil, date: .now) },
                onUndo: { _ in },
                onEditStack: {}
            )
        }
    }
}

#Preview("Light") {
    LogStackSheetPreview()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    LogStackSheetPreview()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    LogStackSheetPreview()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Extra large") {
    LogStackSheetPreview()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Long name") {
    LogStackSheetPreview(firstName: "Phosphatidylserine")
        .modelContainer(previewContainer)
}
