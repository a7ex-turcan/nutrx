import SwiftData
import SwiftUI

/// Supply for one nutrient (nutrx Pro; docs/pro/design/3-supply: supply-form): servings in the bottle, each serving
/// (pre-filled from "each tap adds"), when to remind, an optional price per bottle (#134), the bottle in a sentence,
/// and Refilled today. Saving the first time starts the count from now.
struct SupplySheet: View {
    let nutrient: Nutrient

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The typed count. A String, so what's typed counts straight away (a number-bound field only writes back on
    /// Return, which the number pad doesn't have).
    @State private var servingsText: String
    @State private var servingAmount: Double
    @State private var reminderDays: Int
    @State private var refillToday = false
    @State private var confirmStop = false
    /// The typed price per bottle, in the user's currency; empty = no price.
    @State private var priceText: String
    @FocusState private var focusedField: Field?

    private enum Field { case servings, price }

    /// The typed price, if it's a positive number.
    private var price: Double? {
        guard let value = priceText.parsedDouble, value > 0 else { return nil }
        return value
    }

    private var isSet: Bool { nutrient.supplySetup != nil }
    static let maxServings = 9999
    /// The typed count, clamped to 1…9,999 (0 while the field is empty or not a number).
    private var servings: Int {
        // The locale's own digits and grouping, as the number-bound field read them.
        (try? Int(servingsText, format: .number)).map { min(Self.maxServings, max(0, $0)) } ?? 0
    }
    private static let stepperWidth: CGFloat = 156

    init(nutrient: Nutrient) {
        self.nutrient = nutrient
        _servingsText = State(initialValue: String(Int(nutrient.supplyServings ?? 60)))
        _servingAmount = State(initialValue: nutrient.effectiveServingAmount)
        _reminderDays = State(initialValue: nutrient.refillReminderDays)
        _priceText = State(initialValue: nutrient.supplyPrice.map { $0.formattedAmount(grouped: false) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        NutrientIconTile(nutrient: nutrient, size: 40)
                        Text(nutrient.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 0) {
                        row(title: "Servings in the bottle", hint: "Softgels, tablets, scoops…") {
                            servingsStepper
                        }
                        Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        row(title: "Each serving",
                            hint: servingAmount == nutrient.step ? "Same as “each tap adds”" : "Each tap adds \(amountText(nutrient.step))") {
                            stepper(value: amountText(servingAmount), label: "Each serving",
                                    canDecrease: servingAmount - nutrient.step >= nutrient.step - 1e-9,
                                    decrease: { servingAmount = max(nutrient.step, servingAmount - nutrient.step) },
                                    increase: { servingAmount += nutrient.step })
                        }
                        Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        row(title: "Remind me", hint: "When this many days are left") {
                            stepper(value: reminderDays == 1 ? "1 day" : "\(reminderDays) days", label: "Remind me",
                                    canDecrease: reminderDays > 1,
                                    decrease: { reminderDays = max(1, reminderDays - 1) },
                                    increase: { reminderDays = min(60, reminderDays + 1) })
                        }
                        Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        row(title: "Price per bottle", hint: "Optional, for what it costs a month") {
                            priceField
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text((try? AttributedString(markdown: sentence)) ?? AttributedString(sentence))
                        if let monthlyCost {
                            Text(SupplyText.monthlyCost(monthlyCost) + ".")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)

                    if isSet {
                        VStack(spacing: 8) {
                            Button {
                                refillToday = true
                            } label: {
                                Label(refillToday ? "Count starts today" : "Refilled today",
                                      systemImage: refillToday ? "checkmark" : "arrow.clockwise")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                            .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(refillToday)
                            Text("Starts the count again from a full bottle.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Button("Stop tracking supply", role: .destructive) { confirmStop = true }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.surfaceGround)
            .navigationTitle("Supply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(servings < 1)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .confirmationDialog("Stop tracking \(nutrient.name)'s supply?", isPresented: $confirmStop,
                                titleVisibility: .visible) {
                Button("Stop Tracking", role: .destructive) { stop() }
            } message: {
                Text("Your log stays. Only the bottle count goes.")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Rows

    private func row<Control: View>(title: String, hint: String, @ViewBuilder control: () -> Control) -> some View {
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    text
                    control()
                }
            } else {
                HStack(spacing: 10) {
                    text
                    Spacer(minLength: 8)
                    control()
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    /// The servings capsule: − / + by one, and the number itself can be typed (a bottle of 120 is a lot of taps).
    private var servingsStepper: some View {
        HStack(spacing: 2) {
            stepButton("minus", enabled: servings > 1) { servingsText = String(max(1, servings - 1)) }
            TextField("Servings", text: $servingsText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .servings)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 44, maxWidth: 64)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Servings in the bottle")
            stepButton("plus", enabled: servings < Self.maxServings) {
                servingsText = String(min(Self.maxServings, servings + 1))
            }
        }
        .padding(.horizontal, 4)
        .frame(minWidth: Self.stepperWidth)  // the three capsules line up, as in the design
        .background(Theme.surfaceChip, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// The price capsule, the width of the steppers: the currency symbol and the typed amount.
    private var priceField: some View {
        HStack(spacing: 4) {
            Text(Locale.current.currencySymbol ?? "$")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("None", text: $priceText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .price)
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(minWidth: 44, maxWidth: 90)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(Locale.current.currency.map { "Price per bottle, \($0.identifier)" }
                                    ?? "Price per bottle")
        }
        .padding(.horizontal, 16)
        .frame(minWidth: Self.stepperWidth, minHeight: Theme.minTouchTarget)
        .background(Theme.surfaceChip, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func stepper(value: String, label: String, canDecrease: Bool, decrease: @escaping () -> Void,
                         increase: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            stepButton("minus", enabled: canDecrease, action: decrease)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            stepButton("plus", enabled: true, action: increase)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 4)
        .frame(minWidth: Self.stepperWidth)  // the three capsules line up, as in the design
        .background(Theme.surfaceChip, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: increase()
            case .decrement: if canDecrease { decrease() }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.adjusted()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(symbol == "plus" ? "More" : "Fewer")
    }

    // MARK: - Text

    /// Supply's own estimate of daily use, from the nutrient's logs.
    private var usualDailyUse: Double? {
        let logs = (nutrient.intakeRecords ?? []).map { SupplySchedule.Log(date: $0.date, amount: $0.amount) }
        return SupplySchedule.averageDailyUse(logs: logs)
    }

    /// The share of days the schedule in effect today makes dose days (#134: the same goal fallback as the cost).
    private var doseShare: Double {
        SupplyCost.doseShare(nutrient.schedule().kind(on: .now))
    }

    private var sentence: String {
        SupplyText.bottleSentence(servings: Double(servings), servingAmount: servingAmount, unit: nutrient.unit,
                                  dailyUse: usualDailyUse, goal: nutrient.goalType == .maximum ? nil : nutrient.dailyTarget,
                                  doseShare: doseShare)
    }

    /// What the bottle as set here costs a month, once there's a price.
    private var monthlyCost: Double? {
        let use = SupplyCost.dailyUse(estimate: usualDailyUse, goalType: nutrient.goalType, target: nutrient.dailyTarget,
                                      doseShare: doseShare)
        return SupplyCost.monthly(price: price, bottleAmount: Double(servings) * servingAmount, dailyUse: use)
    }

    private func amountText(_ value: Double) -> String {
        nutrient.unit.isEmpty ? value.formattedAmount() : "\(value.formattedAmount()) \(nutrient.unit)"
    }

    // MARK: - Actions

    private func save() {
        focusedField = nil
        nutrient.supplyServings = Double(min(Self.maxServings, max(1, servings)))
        nutrient.supplyPrice = price
        // nil while it's one step, so a later change to "each tap adds" carries over.
        nutrient.servingAmount = abs(servingAmount - nutrient.step) < 1e-9 ? nil : servingAmount
        nutrient.refillReminderDays = reminderDays
        if nutrient.supplyRefilledAt == nil || refillToday {
            nutrient.refillSupply()
        }
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
        WidgetReload.all()
        dismiss()
    }

    private func stop() {
        nutrient.supplyServings = nil
        nutrient.supplyRefilledAt = nil
        nutrient.servingAmount = nil
        nutrient.supplyPrice = nil
        try? modelContext.save()
        NotificationService.refreshAllNutrientReminders(context: modelContext)
        WidgetReload.all()
        dismiss()
    }
}
