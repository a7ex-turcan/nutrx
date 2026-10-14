import SwiftUI

/// The chip-tinted − amount + capsule of a stack entry (docs/pro/design/1-stacks-export): 44pt tall, the amount in
/// rounded bold at its natural width, − stops at one step. One adjustable element for VoiceOver ("Vitamin D,
/// 2,000 IU", swipe up / down). Used by the stack log sheet (Today) and the stack detail (Settings).
struct StackAmountStepper: View {
    let amount: Double
    let step: Double
    let unit: String
    let nutrientName: String
    let onChange: (Double) -> Void

    private var amountText: String {
        unit.isEmpty ? amount.formattedAmount() : "\(amount.formattedAmount()) \(unit)"
    }

    var body: some View {
        HStack(spacing: 2) {
            stepButton(systemName: "minus", up: false)
                .disabled(amount <= step)
            Text(amountText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            stepButton(systemName: "plus", up: true)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 4)
        .background(Theme.surfaceChip, in: Capsule())
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrientName)
        .accessibilityValue(amountText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(up: true)
            case .decrement: if amount > step { change(up: false) }
            @unknown default: break
            }
        }
    }

    private func stepButton(systemName: String, up: Bool) -> some View {
        Button {
            change(up: up)
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                .contentShape(Rectangle())
        }
    }

    private func change(up: Bool) {
        Haptics.adjusted()
        onChange(StackLogging.stepped(amount, by: step, up: up))
    }
}

#Preview {
    VStack(spacing: 12) {
        StackAmountStepper(amount: 2000, step: 1000, unit: "IU", nutrientName: "Vitamin D") { _ in }
        StackAmountStepper(amount: 0.25, step: 0.25, unit: "L", nutrientName: "Water") { _ in }
    }
    .padding()
}
