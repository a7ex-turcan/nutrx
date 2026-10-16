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

    private var entries: [LogStackEntry] { StackLogging.activeEntries(of: stack) }

    /// Rows that fit above the Log button at the medium detent.
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

                if let logged {
                    doneFooter(logged)
                } else {
                    logFooter
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surfaceGround)
        // At accessibility sizes half a screen holds only the header and one row, so it opens full height. Half
        // height fits three rows and the Log button; with more it opens full height, so the button isn't below the
        // edge (it can still be dragged down).
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large],
                             selection: dynamicTypeSize.isAccessibilitySize ? .constant(.large) : $detent)
        .presentationDragIndicator(.visible)
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
                Text(logged != nil && progress.countsAsMet
                     ? "\(progress.currentText) \(progress.goalText) · Done"
                     : "\(progress.currentText) \(progress.goalText)")
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
        return Group {
            // At accessibility sizes the amount goes under the name, so neither is broken mid-word.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    summary
                    trailing(entry, nutrient: nutrient)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    summary
                    Spacer(minLength: 8)
                    trailing(entry, nutrient: nutrient)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 12)
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

    // Rendered inline: preview snapshots don't capture presented sheets.
    var body: some View {
        if let stack = stacks.first {
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
