import SwiftUI

/// Draft state for creating or editing a nutrient.
/// Used by both onboarding and the My Nutrients form.
@Observable
final class NutrientDraft {
    var name: String = ""
    var unit: String = ""
    var step: String = ""
    var dailyTarget: String = ""
    var notes: String = ""
    var pendingReminderTimes: [Date] = []
    var goalType: GoalType = .minimum
    var upperBound: String = ""
    var tint: NutrientTint = .green
    var symbolName: String = NutrientDraft.defaultSymbol
    /// Servings in the bottle, from a scanned label (nutrx Pro): set, it starts supply tracking when the nutrient is
    /// added. New nutrients only.
    var supplyServings: String = ""
    /// Fields filled from a scanned label, which show "from label" until edited.
    var scannedFields: Set<ScannedField> = []
    /// Fields a scan couldn't read, which ask for them.
    var unreadFields: Set<ScannedField> = []
    /// What one serving is ("softgels"), from the label, for "120 softgels".
    var servingForm: String?

    /// The fields "Scan a label" fills.
    enum ScannedField: Hashable, CaseIterable {
        case name, unit, step, supply
    }

    var wasScanned: Bool { !scannedFields.isEmpty || !unreadFields.isEmpty }

    static let defaultSymbol = "pills"

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && (step.parsedDouble ?? 0) > 0
            && (dailyTarget.parsedDouble ?? 0) > 0
            && rangeIsValid
    }

    /// Shown under the goal fields when a range's maximum isn't above its minimum.
    var rangeError: String? {
        guard goalType == .range,
              let lower = dailyTarget.parsedDouble,
              let upper = upperBound.parsedDouble,
              upper <= lower else { return nil }
        return "The maximum has to be more than the minimum."
    }

    private var rangeIsValid: Bool {
        guard goalType == .range else { return true }
        guard let lower = dailyTarget.parsedDouble,
              let upper = upperBound.parsedDouble else { return false }
        return upper > lower
    }

    func reset() {
        name = ""
        unit = ""
        step = ""
        dailyTarget = ""
        notes = ""
        pendingReminderTimes = []
        goalType = .minimum
        upperBound = ""
        tint = .green
        symbolName = Self.defaultSymbol
        supplyServings = ""
        scannedFields = []
        unreadFields = []
        servingForm = nil
    }

    func populate(from nutrient: Nutrient) {
        name = nutrient.name
        unit = nutrient.unit
        step = Self.editableText(nutrient.step)
        dailyTarget = Self.editableText(nutrient.dailyTarget)
        notes = nutrient.notes ?? ""
        goalType = nutrient.goalType
        upperBound = nutrient.upperBound.map { Self.editableText($0) } ?? ""
        tint = nutrient.tint
        symbolName = nutrient.symbolName
    }

    /// Adds a reminder time for a not-yet-saved nutrient, keeping the list sorted by time of day.
    /// Returns false (and adds nothing) if that hour and minute is already there — two would map to the
    /// same `nutrient-…-reminder-HHmm` notification.
    @discardableResult
    func addPendingReminder(_ time: Date, calendar: Calendar = .current) -> Bool {
        guard !hasPendingReminder(at: time, calendar: calendar) else { return false }
        pendingReminderTimes.append(time)
        pendingReminderTimes.sort { Self.hourMinute($0, calendar) < Self.hourMinute($1, calendar) }
        return true
    }

    /// Whether a reminder at this hour and minute is already in the list.
    func hasPendingReminder(at time: Date, calendar: Calendar = .current) -> Bool {
        pendingReminderTimes.contains { Self.hourMinute($0, calendar) == Self.hourMinute(time, calendar) }
    }

    private static func hourMinute(_ date: Date, _ calendar: Calendar) -> (Int, Int) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    /// A number as the user would type it: current locale's decimal separator, no grouping, no trailing ".0".
    static func editableText(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...6)))
    }
}

/// The focusable fields of `NutrientFormFields`. Focus is owned by the container so it can put the keyboard's
/// Done button at the root of its toolbar — declared inside the scroll view's content, a keyboard toolbar
/// caused attribute-graph cycles when the keyboard first appeared.
enum NutrientFormField: Hashable {
    case name, unit, step, dailyTarget, upperBound, notes
}

/// Reusable fields for creating or editing a nutrient (DESIGN.md §5.7): name + unit, "Look" (tint and
/// symbol), "Daily goal" (goal type, target(s), step) and notes. Consumers provide the container.
struct NutrientFormFields<BeforeNotes: View>: View {
    @Bindable var draft: NutrientDraft
    var focusedField: FocusState<NutrientFormField?>.Binding
    /// Rows the container wants between the goal and the notes (the form sheet's Group / Reminders).
    @ViewBuilder var beforeNotes: BeforeNotes

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            nameAndUnit

            sectionHeader("Look")
            VStack(spacing: Theme.Spacing.cardPadding) {
                TintPicker(selection: $draft.tint)
                SymbolPicker(selection: $draft.symbolName, tint: draft.tint)
            }
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.surfaceCard, in: cardShape)

            sectionHeader("Daily goal")
            GoalTypePicker(selection: $draft.goalType, tint: draft.tint)
            goalFields

            if let rangeError {
                Text(rangeError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textAmberInk)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            beforeNotes
                .padding(.top, 6)

            notesField
                .padding(.top, 6)
        }
        .animation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25)), value: draft.goalType)
        .animation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2)), value: rangeError)
    }

    // MARK: - Sections

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
    }

    private var nameAndUnit: some View {
        fieldPair(
            labelled("Name", id: .name) {
                TextField("e.g. Vitamin D", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: .name)
                    .accessibilityLabel("Name")
            },
            labelled("Unit", id: .unit) {
                TextField("e.g. mg, IU", text: $draft.unit)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: .unit)
                    .accessibilityLabel("Unit")
            }
        )
        .background(Theme.surfaceCard, in: cardShape)
    }

    private var goalFields: some View {
        VStack(spacing: 0) {
            if draft.goalType == .range {
                fieldPair(
                    labelled("Minimum, per day", id: .dailyTarget) {
                        amountField($draft.dailyTarget, focus: .dailyTarget, label: "Minimum, per day")
                    },
                    labelled("Maximum", id: .upperBound) {
                        amountField($draft.upperBound, focus: .upperBound, label: "Maximum")
                    }
                )
                rowDivider
                labelled("Each tap adds", id: .step) {
                    amountField($draft.step, focus: .step, label: "Each tap adds")
                }
            } else {
                let goalLabel = "\(GoalTypePicker.label(for: draft.goalType)), per day"
                fieldPair(
                    labelled(goalLabel, id: .dailyTarget) {
                        amountField($draft.dailyTarget, focus: .dailyTarget, label: goalLabel)
                    },
                    labelled("Each tap adds", id: .step) {
                        amountField($draft.step, focus: .step, label: "Each tap adds")
                    }
                )
            }
        }
        .background(Theme.surfaceCard, in: cardShape)
    }

    private var notesField: some View {
        labelled("Notes", id: .notes) {
            TextField("Why you take it, best time to take it…", text: $draft.notes, axis: .vertical)
                .lineLimit(1...4)
                .focused(focusedField, equals: .notes)
                .accessibilityLabel("Notes")
        }
        .background(Theme.surfaceCard, in: cardShape)
    }

    // MARK: - Pieces

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }

    /// Vertical hairline between two columns, drawn as an overlay so the row doesn't need
    /// `fixedSize` (which fed back into the self-sizing text fields when the keyboard appeared).
    private var columnDivider: some View {
        Rectangle().fill(Theme.lineHairline).frame(width: 1)
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.lineHairline).frame(height: 1)
    }

    /// Two fields side by side, stacked at accessibility text sizes so neither label nor value is squeezed.
    @ViewBuilder
    private func fieldPair(_ first: some View, _ second: some View) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                first
                rowDivider
                second
            }
        } else {
            HStack(spacing: 0) {
                first
                second.overlay(alignment: .leading) { columnDivider }
            }
        }
    }

    /// The caption above a field. VoiceOver skips it: each field carries the same text as its own label, so a
    /// value never reads as just its placeholder ("e.g. Vitamin D", "0"). `id` lets a scrolling container bring the
    /// field above the keyboard when it's focused.
    private func labelled(_ label: String, id: NutrientFormField, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            content()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(id)
    }

    /// Big rounded number with the unit after it ("5 g"). VoiceOver reads "Each tap adds, g, 5".
    private func amountField(_ text: Binding<String>, focus: NutrientFormField, label: String) -> some View {
        let unit = draft.unit.trimmingCharacters(in: .whitespaces)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused(focusedField, equals: focus)
                .fixedSize()
                .accessibilityLabel(unit.isEmpty ? label : "\(label), \(unit)")
            Text(unit)
                .lineLimit(1)
                .accessibilityHidden(true)  // in the field's label
        }
        .font(.system(.title3, design: .rounded, weight: .bold))
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField.wrappedValue = focus }
    }

    private var rangeError: String? { draft.rangeError }
}

extension NutrientFormFields where BeforeNotes == EmptyView {
    init(draft: NutrientDraft, focusedField: FocusState<NutrientFormField?>.Binding) {
        self.init(draft: draft, focusedField: focusedField) { EmptyView() }
    }
}

private struct NutrientFormFieldsPreview: View {
    @State private var draft: NutrientDraft = {
        let draft = NutrientDraft()
        draft.name = "Creatine"
        draft.unit = "g"
        draft.dailyTarget = "5"
        draft.step = "5"
        draft.tint = .teal
        draft.symbolName = "waterbottle"
        return draft
    }()

    @FocusState private var focusedField: NutrientFormField?

    var body: some View {
        NavigationStack {
            ScrollView {
                NutrientFormFields(draft: draft, focusedField: $focusedField)
                    .padding(Theme.Spacing.screenMargin)
            }
            .background(Theme.surfaceGround)
        }
    }
}

#Preview("Light") {
    NutrientFormFieldsPreview()
}

#Preview("Dark") {
    NutrientFormFieldsPreview()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    NutrientFormFieldsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}
