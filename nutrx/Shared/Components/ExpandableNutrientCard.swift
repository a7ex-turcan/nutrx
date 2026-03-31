import SwiftUI

struct ExpandableNutrientCard: View {
    let nutrient: Nutrient
    let currentIntake: Double
    let isExpanded: Bool
    var onToggle: () -> Void
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?

    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            NutrientRowView(
                nutrient: nutrient,
                currentIntake: currentIntake,
                onIncrement: onIncrement,
                onDecrement: onDecrement
            )

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                NutrientIntakeHistoryView(nutrientID: nutrient.id, unit: nutrient.unit)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .opacity(contentVisible ? 1 : 0)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                withAnimation(.easeIn(duration: 0.15).delay(0.05)) {
                    contentVisible = true
                }
            } else {
                contentVisible = false
            }
        }
    }
}
