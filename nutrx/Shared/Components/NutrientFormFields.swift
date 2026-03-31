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

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && (step.parsedDouble ?? 0) > 0
            && (dailyTarget.parsedDouble ?? 0) > 0
    }

    func reset() {
        name = ""
        unit = ""
        step = ""
        dailyTarget = ""
        notes = ""
        pendingReminderTimes = []
    }

    func populate(from nutrient: Nutrient) {
        name = nutrient.name
        unit = nutrient.unit
        step = String(nutrient.step)
        dailyTarget = String(nutrient.dailyTarget)
        notes = nutrient.notes ?? ""
    }
}

/// Reusable form fields for creating or editing a nutrient.
/// Consumers provide the container (sheet, inline section, etc.).
struct NutrientFormFields: View {
    @Bindable var draft: NutrientDraft
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, unit, step, dailyTarget, notes
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

            HStack(spacing: 12) {
                FormField(label: "Step") {
                    TextField("e.g. 1, 0.5, 100", text: $draft.step)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .step)
                }

                FormField(label: "Daily Target") {
                    TextField("e.g. 2000", text: $draft.dailyTarget)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .dailyTarget)
                }
            }

            FormField(label: "Notes") {
                TextField("Why you're tracking this, best time to take it…", text: $draft.notes)
                    .focused($focusedField, equals: .notes)
            }
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
