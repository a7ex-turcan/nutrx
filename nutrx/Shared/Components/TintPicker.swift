import SwiftUI

/// The eight nutrient tints as 34pt swatches; the selected one gets a card-coloured gap and a tint ring
/// (DESIGN.md §4.10). Each swatch's hit area is an eighth of the row and 44pt tall, so the row fits the form's
/// card on every iPhone (eight fixed 44pt frames need 352pt, more than a 375pt or 393pt phone has).
struct TintPicker: View {
    @Binding var selection: NutrientTint

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NutrientTint.allCases, id: \.self) { tint in
                swatch(tint)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Colour")
    }

    private func swatch(_ tint: NutrientTint) -> some View {
        let isSelected = tint == selection
        return Button {
            selection = tint
        } label: {
            Circle()
                .fill(tint.color)
                .frame(width: 34, height: 34)
                .padding(isSelected ? 3 : 0)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(tint.color, lineWidth: 2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(tint.rawValue.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Light") {
    @Previewable @State var tint = NutrientTint.teal
    TintPicker(selection: $tint)
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
}

#Preview("Dark") {
    @Previewable @State var tint = NutrientTint.coral
    TintPicker(selection: $tint)
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .padding(Theme.Spacing.screenMargin)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceGround)
        .preferredColorScheme(.dark)
}
