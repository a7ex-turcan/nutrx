import SwiftUI

/// Three cards — At least / At most / Between — each with a tiny bar showing the idea; the selected card
/// gets a forest border and its bar takes the nutrient's tint (DESIGN.md §4.10). Replaces the segmented picker.
struct GoalTypePicker: View {
    @Binding var selection: GoalType
    let tint: NutrientTint

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            ForEach(GoalType.allCases, id: \.self) { goalType in
                card(goalType)
            }
        }
    }

    static func label(for goalType: GoalType) -> String {
        switch goalType {
        case .minimum: "At least"
        case .maximum: "At most"
        case .range: "Between"
        }
    }

    /// Where the filled part of the illustration bar sits: (start, width) as fractions of the track.
    private func illustration(for goalType: GoalType) -> (start: CGFloat, width: CGFloat) {
        switch goalType {
        case .minimum: (0, 0.7)
        case .maximum: (0, 0.45)
        case .range: (0.35, 0.3)
        }
    }

    private func card(_ goalType: GoalType) -> some View {
        let isSelected = goalType == selection
        let bar = illustration(for: goalType)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return Button {
            selection = goalType
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Shapes rather than a GeometryReader: three readers here caused attribute-graph cycles
                // when the keyboard first changed the sheet's safe area.
                Capsule()
                    .fill(Theme.lineHairline)
                    .overlay {
                        BarSegment(start: bar.start, width: bar.width)
                            .fill(isSelected ? tint.color : Theme.textSecondary.opacity(0.5))
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)

                Spacer(minLength: 12)

                Text(Self.label(for: goalType))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Theme.surfaceCard, in: shape)
            .overlay {
                if isSelected {
                    // Control/Primary = forest in light (§4.10), green in dark where forest disappears.
                    shape.strokeBorder(Theme.controlPrimary, lineWidth: 2)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(Self.label(for: goalType))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A capsule covering `start ..< start + width` (fractions) of its rect.
private struct BarSegment: Shape {
    let start: CGFloat
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let segment = CGRect(x: rect.minX + rect.width * start, y: rect.minY,
                             width: rect.width * width, height: rect.height)
        return Capsule().path(in: segment)
    }
}

private struct GoalTypePickerPreviewGallery: View {
    @State private var goalType = GoalType.minimum

    var body: some View {
        GoalTypePicker(selection: $goalType, tint: .teal)
            .padding(Theme.Spacing.screenMargin)
            .frame(maxHeight: .infinity)
            .background(Theme.surfaceGround)
    }
}

#Preview("Light") {
    GoalTypePickerPreviewGallery()
}

#Preview("Dark") {
    GoalTypePickerPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    GoalTypePickerPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}
