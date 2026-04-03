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

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && (step.parsedDouble ?? 0) > 0
            && (dailyTarget.parsedDouble ?? 0) > 0
            && rangeIsValid
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
    }

    func populate(from nutrient: Nutrient) {
        name = nutrient.name
        unit = nutrient.unit
        step = String(nutrient.step)
        dailyTarget = String(nutrient.dailyTarget)
        notes = nutrient.notes ?? ""
        goalType = nutrient.goalType
        if let ub = nutrient.upperBound {
            upperBound = String(ub)
        } else {
            upperBound = ""
        }
    }
}

/// Reusable form fields for creating or editing a nutrient.
/// Consumers provide the container (sheet, inline section, etc.).
struct NutrientFormFields: View {
    @Bindable var draft: NutrientDraft
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, unit, step, dailyTarget, upperBound, notes
    }

    var body: some View {
        VStack(spacing: 16) {
            FormField(label: "Name") {
                TextField("e.g. Vitamin D, Caffeine", text: $draft.name)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
            }

            FormField(label: "Unit") {
                TextField("e.g. mg, g, IU, cups", text: $draft.unit)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .unit)
            }

            // Goal type section
            VStack(alignment: .leading, spacing: 10) {
                Text("Goal type")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Goal type", selection: $draft.goalType) {
                    Text("At least").tag(GoalType.minimum)
                    Text("At most").tag(GoalType.maximum)
                    Text("Between").tag(GoalType.range)
                }
                .pickerStyle(.segmented)

                Text(goalCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.none, value: draft.goalType)

                NutrientProgressBar(
                    current: previewCurrent,
                    target: previewTarget,
                    goalType: draft.goalType,
                    upperBound: previewUpperBound
                )
                .frame(height: 10)
                .padding(.horizontal, 4)
            }

            HStack(spacing: 12) {
                FormField(label: "Step") {
                    TextField("e.g. 1, 0.5, 100", text: $draft.step)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .step)
                }

                FormField(label: draft.goalType == .range ? "Minimum" : "Daily Target") {
                    TextField("e.g. 2000", text: $draft.dailyTarget)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .dailyTarget)
                }
            }

            if draft.goalType == .range {
                FormField(label: "Maximum") {
                    TextField("e.g. 4000", text: $draft.upperBound)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .upperBound)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            FormField(label: "Notes") {
                TextField("Why you're tracking this, best time to take it…", text: $draft.notes)
                    .focused($focusedField, equals: .notes)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: draft.goalType)
    }

    // MARK: - Goal Caption

    private var goalCaption: String {
        let targetStr = draft.dailyTarget.parsedDouble?.displayString ?? "your target"
        let unitStr = draft.unit.trimmingCharacters(in: .whitespaces).isEmpty ? "units" : draft.unit.trimmingCharacters(in: .whitespaces)

        switch draft.goalType {
        case .minimum:
            return "Your bar fills green when you hit \(targetStr) \(unitStr) or more."
        case .maximum:
            return "Your bar turns orange if you go over \(targetStr) \(unitStr)."
        case .range:
            let upperStr = draft.upperBound.parsedDouble?.displayString ?? "your max"
            return "Your bar is green when you stay between \(targetStr) and \(upperStr) \(unitStr)."
        }
    }

    // MARK: - Preview Bar Values

    private var previewTarget: Double {
        draft.dailyTarget.parsedDouble ?? 100
    }

    private var previewUpperBound: Double? {
        guard draft.goalType == .range else { return nil }
        return draft.upperBound.parsedDouble ?? (previewTarget * 2)
    }

    private var previewCurrent: Double {
        switch draft.goalType {
        case .minimum:
            return previewTarget * 0.6
        case .maximum:
            return previewTarget * 0.7
        case .range:
            // Mid-range value (green zone)
            let upper = previewUpperBound ?? (previewTarget * 2)
            return (previewTarget + upper) / 2
        }
    }

    func dismissKeyboard() {
        focusedField = nil
    }
}

#Preview {
    ScrollView {
        NutrientFormFields(draft: NutrientDraft())
            .padding(24)
    }
    .background(Color(.systemGroupedBackground))
}
