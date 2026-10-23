import SwiftData
import SwiftUI

/// Log an exact amount and review today's entries for one nutrient (DESIGN.md §4.6).
/// Opened from Today by tapping a card, the leading swipe action, or "Add Exact Amount".
struct LogSheet: View {
    let nutrient: Nutrient
    /// Logs `amount` with an optional note. The sheet dismisses itself afterwards.
    let onLog: (_ amount: Double, _ note: String?) -> Void
    /// Deletes one of today's entries.
    let onDelete: (IntakeRecord) -> Void
    /// Opened from Not today (#132): a line saying the log won't count today (#247).
    let notDueNote: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.widthClass) private var widthClass
    @Query private var records: [IntakeRecord]
    @State private var amountText: String
    /// The chip the user last tapped — wins when several chips share the current amount.
    @State private var tappedChipID: String? = "1x"
    @State private var note = ""
    @FocusState private var focusedField: Field?
    /// The on-screen keyboard is up, so Log moves above it (#221). Focus alone isn't enough: with a hardware keyboard
    /// nothing covers Log, and it stays under the note.
    @State private var keyboardShown = false
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 52
    /// The sheet's width, the unit's width and the amount's width at `amountFontSize`, so the amount can shrink to
    /// leave the unit whole (#242).
    @State private var sheetWidth: CGFloat = 0
    @State private var unitWidth: CGFloat = 0
    @State private var amountTextWidth: CGFloat = 0

    private enum Field { case amount, note }

    init(nutrient: Nutrient, notDueNote: String? = nil, onLog: @escaping (Double, String?) -> Void,
         onDelete: @escaping (IntakeRecord) -> Void) {
        self.nutrient = nutrient
        self.notDueNote = notDueNote
        self.onLog = onLog
        self.onDelete = onDelete
        _amountText = State(initialValue: nutrient.step.formattedAmount(maxFractionDigits: Self.precision))

        let nutrientID = nutrient.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        _records = Query(
            filter: #Predicate<IntakeRecord> {
                $0.nutrient?.id == nutrientID && $0.date >= startOfDay && $0.date < endOfDay
            },
            sort: \IntakeRecord.date
        )
    }

    // MARK: - Derived state

    /// Today's total, summed from the same records the list shows.
    private var progress: GoalProgress {
        GoalProgress(nutrient: nutrient, current: records.reduce(0) { $0 + $1.amount })
    }

    /// The amount to log, if the field holds a positive number.
    private var amount: Double? {
        guard let value = amountText.parsedDouble, value > 0 else { return nil }
        return value
    }

    /// The 52pt amount, scaled with Dynamic Type up to its xxxLarge size (~62pt — beyond that the unit no
    /// longer fits between − and +), and shrunk for long values (a TextField can't use `minimumScaleFactor`).
    private var amountFontSize: CGFloat {
        let size = min(amountSize, 62)
        let characters = max(amountText.count, 1)
        return characters > 6 ? size * max(6 / CGFloat(characters), 0.5) : size
    }

    /// `amountFontSize`, smaller when the amount and its unit don't both fit between − and +: at xxxLarge on an
    /// iPhone SE the unit was squeezed to a sliver ("IU" read "IL", #242). The amount is measured off-screen at
    /// `amountFontSize`, never at this size, so the measuring can't feed back into itself.
    private var fittedAmountFontSize: CGFloat {
        // Between − and +, from the sheet's width (not the row's, which an amount too wide would have widened).
        let rowWidth = sheetWidth - 2 * Self.contentMargin - 2 * Stepper.padding - 2 * Stepper.buttonSize
            - 2 * Stepper.spacing
        // The text field draws a little wider than its text.
        let room = rowWidth - unitWidth - Stepper.unitSpacing - 4
        return Self.fittedAmountSize(base: amountFontSize, textWidth: amountTextWidth, room: room)
    }

    /// `base`, or smaller in proportion when text `textWidth` wide at `base` doesn't fit in `room`; never below 40%.
    /// Nothing measured yet, or no room at all: `base`.
    static func fittedAmountSize(base: CGFloat, textWidth: CGFloat, room: CGFloat) -> CGFloat {
        guard textWidth > 0, room > 0, textWidth > room else { return base }
        return max(base * room / textWidth, base * 0.4)
    }

    /// The sheet content's side margin.
    private static let contentMargin: CGFloat = 20

    /// The amount stepper's measures, shared by its layout and `fittedAmountFontSize`.
    private enum Stepper {
        static let padding: CGFloat = 12
        static let buttonSize: CGFloat = 48
        static let spacing: CGFloat = 8
        /// Between the amount and its unit.
        static let unitSpacing: CGFloat = 6
    }

    private var amountLabel: String {
        "\(amount?.formattedAmount(maxFractionDigits: Self.precision) ?? "0") \(nutrient.unit)"
            .trimmingCharacters(in: .whitespaces)
    }

    /// Decimals kept in the editable amount and the Log button, so a 0.125 step logs 0.125 (not 0.13).
    private static let precision = 6

    /// Single-select: the tapped chip while its value still matches the amount, else the first chip that does.
    private var selectedChipID: String? {
        guard let amount else { return nil }
        let matching = quickAmounts.filter { Self.isSame($0.value, amount) }
        if let tappedChipID, matching.contains(where: { $0.id == tappedChipID }) { return tappedChipID }
        return matching.first?.id
    }

    /// Equality that tolerates float drift (0.8 − 0.1 vs a typed "0.7").
    private static func isSame(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= 1e-9 * max(1, abs(b))
    }

    private struct QuickAmount: Identifiable {
        let id: String
        let label: String
        let value: Double
        var isFillToGoal = false
    }

    /// ½× / 1× / 2× step, plus "Fill to goal" when there's a target left to reach, and it's due today: from Not
    /// today a log won't count toward the goal, which the sheet says (#256).
    private var quickAmounts: [QuickAmount] {
        let step = nutrient.step
        var chips = [0.5, 1, 2].map { factor in
            QuickAmount(id: "\(factor)x", label: (step * factor).formattedAmount(maxFractionDigits: Self.precision),
                        value: step * factor)
        }
        if notDueNote == nil, let remaining = progress.amountToGoal {
            chips.append(QuickAmount(id: "fill", label: "Fill to goal", value: remaining, isFillToGoal: true))
        }
        return chips
    }

    // MARK: - Body

    var body: some View {
        // The NavigationStack (bar hidden) is only there so the keyboard toolbar — the Done button for the
        // return-less .decimalPad — actually renders; outside one it doesn't.
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField = nil }
                            .fontWeight(.semibold)
                    }
                }
        }
        // On iPhone half height first, then full. From regular widths a centred form sheet (LAYOUT.md: about 540 pt
        // wide): at the medium detent the iPad cut off "Logged today" (#151). Sizing doesn't change an iPhone sheet.
        // Half height is taller where it would cut off the Log button (the folded iPhone Duo, #212).
        .presentationDetents(widthClass == .compact ? [.custom(HalfThroughLogButton.self), .large] : [.large])
        .presentationSizing(.form)
        .presentationDragIndicator(widthClass == .compact ? .visible : .hidden)  // nothing to resize in a form sheet
        .presentationBackground(Theme.surfaceCard)
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.bottom, notDueNote == nil ? 8 : 0)
                    if let notDueNote {
                        Label(notDueNote, systemImage: "calendar")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    amountStepper
                    quickAmountChips
                    noteField
                        .id(Field.note)
                    if !pinsLog {
                        logButton
                            // Its bottom edge in the content, plus a margin: how tall the half-height detent must be.
                            .onGeometryChange(for: CGFloat.self) {
                                $0.frame(in: .named(Self.contentSpace)).maxY
                            } action: {
                                HalfThroughLogButton.heightThroughButton = $0 + 16
                            }
                    }
                    loggedToday
                        .padding(.top, 10)
                }
                .padding(.horizontal, Self.contentMargin)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .coordinateSpace(.named(Self.contentSpace))
                .id(Self.topID)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { sheetWidth = $0 }
            .scrollDismissesKeyboard(.interactively)
            // While typing, Log sits on the keyboard's bar instead, and the field being typed in scrolls into view
            // above it: in the content it ended up under the bar and its Done button on an iPhone SE (#221).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pinsLog {
                    logButton
                        .padding(.horizontal, Self.contentMargin)
                        .padding(.vertical, 8)
                        // Down through the keyboard's bar too, so the content doesn't show around its Done button.
                        .background { Theme.surfaceCard.ignoresSafeArea(.all, edges: .bottom) }
                }
            }
            // The note field scrolls only its line into view, so bring its whole box above Log: once the keyboard
            // has risen (the first time after launch it takes longer than any fixed wait), and after switching to it
            // with the keyboard already up. Once the keyboard is gone, back to the top, which the half-height sheet
            // shows down to Log (the scroll stayed where typing left it, cutting off the name at the largest sizes).
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if focusedField == .note { scroll(proxy, to: Field.note, anchor: .bottom) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardShown = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardShown = false
            }
            .task(id: focusedField) {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                switch focusedField {
                case .note: scroll(proxy, to: Field.note, anchor: .bottom)
                case nil: scroll(proxy, to: Self.topID, anchor: .top)
                case .amount: break
                }
            }
        }
        .background(Theme.surfaceCard)
    }

    private static let contentSpace = "logSheetContent"
    private static let topID = "logSheetTop"

    /// Log sits above the keyboard rather than under the note.
    private var pinsLog: Bool { focusedField != nil && keyboardShown }

    private func scroll(_ proxy: ScrollViewProxy, to id: some Hashable, anchor: UnitPoint) {
        withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProgressRing(nutrient: nutrient, progress: progress)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.name)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Text(progress.currentText).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Theme.textPrimary)) of \(progress.goalAmountText) today")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
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
            .accessibilityLabel("Close")
        }
    }

    private var amountStepper: some View {
        HStack(spacing: Stepper.spacing) {
            stepButton(systemName: "minus", label: "Decrease amount") {
                setAmount(max(0, (amount ?? 0) - nutrient.step))
            }
            .disabled((amount ?? 0) <= 0)

            VStack(spacing: 4) {
                Text("Amount")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Stepper.unitSpacing) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .font(.system(size: fittedAmountFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .fixedSize()
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityLabel("Amount in \(nutrient.unit)")
                    Text(nutrient.unit)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { unitWidth = $0 }
                }
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .background {
                    Text(amountText.isEmpty ? "0" : amountText)
                        .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { amountTextWidth = $0 }
                }
            }
            .frame(maxWidth: .infinity)

            stepButton(systemName: "plus", label: "Increase amount") {
                setAmount((amount ?? 0) + nutrient.step)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, Stepper.padding)
        .background(Theme.surfaceGround, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func stepButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.adjusted()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Stepper.buttonSize, height: Stepper.buttonSize)
                .background(Theme.surfaceCard, in: Circle())
                .shadow(color: Theme.textPrimary.opacity(0.08), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(label)
    }

    private var quickAmountChips: some View {
        let chips = HStack(spacing: 8) {
            ForEach(quickAmounts) { chip in
                quickAmountChip(chip)
            }
        }
        return ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
    }

    private func quickAmountChip(_ chip: QuickAmount) -> some View {
        let isSelected = selectedChipID == chip.id
        return Button {
            setAmount(chip.value)
            tappedChipID = chip.id
        } label: {
            Text(chip.label)
                .font(chip.isFillToGoal ? .subheadline.weight(.semibold)
                                        : .system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Theme.controlOnPrimary
                                 : chip.isFillToGoal ? Theme.textGreenInk : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.minTouchTarget)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.controlPrimary)
                    } else if chip.isFillToGoal {
                        Capsule().fill(Theme.green.opacity(0.10))
                        Capsule().strokeBorder(Theme.green, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    } else {
                        Capsule().strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                    }
                }
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.isFillToGoal
                            ? "Fill to goal, \(chip.value.formattedAmount(maxFractionDigits: Self.precision)) \(nutrient.unit)"
                                              : "\(chip.label) \(nutrient.unit)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("e.g. with breakfast", text: $note)
                .focused($focusedField, equals: .note)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                }
        }
    }

    private var logButton: some View {
        Button {
            guard let amount else { return }
            Haptics.logged(reachingGoal: progress.reachesGoal(adding: amount))
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            onLog(amount, trimmed.isEmpty ? nil : trimmed)
            dismiss()
        } label: {
            let enabled = amount != nil
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .fontWeight(.bold)
                    // GreenSoft accent on forest; on the dark-mode green button it would vanish.
                    .foregroundStyle(!enabled ? Theme.textSecondary
                                     : colorScheme == .dark ? Theme.controlOnPrimary : Theme.greenSoft)
                // No amount yet: just "Log", not "Log 0 mg".
                Text(enabled ? "Log \(amountLabel)" : "Log")
                    .monospacedDigit()
            }
            .font(.headline)
            // Disabled (no valid amount): chip grey with secondary text, legible in both appearances. Fading the
            // green to 50% left the label at about 2:1 (#20); same style as onboarding's Start tracking.
            .foregroundStyle(enabled ? Theme.controlOnPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(enabled ? Theme.controlPrimary : Theme.surfaceChip,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                // On the sheet's white card the chip fill alone barely shows, so the disabled button gets the
                // ghost outline the stepper buttons use.
                if !enabled {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(amount == nil)
    }

    private var loggedToday: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Logged today")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(records.count == 1 ? "1 entry" : "\(records.count) entries")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            if records.isEmpty {
                Text("Nothing logged yet today.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(records, id: \.persistentModelID) { record in
                        entryRow(record)
                        Divider().overlay(Theme.lineHairline)
                    }
                }
            }
        }
    }

    private func entryRow(_ record: IntakeRecord) -> some View {
        let isDecrement = record.amount < 0
        let signedAmount = "\(isDecrement ? "−" : "+")\(abs(record.amount).formattedAmount(maxFractionDigits: Self.precision)) \(nutrient.unit)"

        return HStack(spacing: 12) {
            Text(record.date, format: .dateTime.hour().minute())
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)

            Circle()
                .fill(nutrient.tint.color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(signedAmount)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isDecrement ? Theme.textSecondary : Theme.textPrimary)
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Button {
                Haptics.deleted()
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) {
                    onDelete(record)
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete entry")
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .contain)
    }

    private func setAmount(_ value: Double) {
        amountText = value.formattedAmount(maxFractionDigits: Self.precision)
    }
}

/// Half the screen, like `.medium`, or taller when that would cut off the Log button: on the folded iPhone Duo
/// (678 pt tall) half height ended above it (#212).
private struct HalfThroughLogButton: CustomPresentationDetent {
    /// How tall the sheet must be to show the Log button (a detent's height leaves out the home indicator's inset),
    /// set by `LogSheet` from its layout; 0 until measured. A detent's context reads the presenting view's
    /// environment, not the sheet's, so the sheet hands it over here.
    static var heightThroughButton: CGFloat = 0

    static func height(in context: Context) -> CGFloat? {
        min(max(context.maxDetentValue / 2, heightThroughButton), context.maxDetentValue)
    }
}

// MARK: - Previews

private struct LogSheetPreview: View {
    var notDueNote: String?
    @Query(filter: #Predicate<Nutrient> { $0.name == "Vitamin D" }) private var nutrients: [Nutrient]

    // Rendered inline: preview snapshots don't capture presented sheets.
    var body: some View {
        if let nutrient = nutrients.first {
            LogSheet(nutrient: nutrient, notDueNote: notDueNote, onLog: { _, _ in }, onDelete: { _ in })
                .background(Theme.surfaceCard)
        }
    }
}

#Preview("Light") {
    LogSheetPreview()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    LogSheetPreview()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    LogSheetPreview()
        .modelContainer(previewContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Not due today") {
    LogSheetPreview(notDueNote: "Not due today, so this won't count toward your goal. Next: Sunday.")
        .modelContainer(previewContainer)
}
