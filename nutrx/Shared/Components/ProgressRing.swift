import SwiftUI

/// Circular progress: track + arc with round caps, starting at 12 o'clock (DESIGN.md §4.1).
/// The caller sets the size with `.frame`; used at 52/5 (Today card), 56/5 (log sheet),
/// 40/5 (widget, Watch) and 34/6 (medium widget).
struct ProgressRing: View {
    let fraction: Double
    let color: Color
    let trackColor: Color
    var lineWidth: CGFloat = 5
    /// SF Symbol drawn in the centre, in `symbolColor`.
    var symbolName: String? = nil
    var symbolColor: Color? = nil
    /// Green check badge at the bottom-right, for met / in-range goals.
    var showsCheck: Bool = false
    /// VoiceOver label (nutrient name) and value ("2,000 of 4,000 IU"). The value defaults to a percentage.
    var label: String? = nil
    var valueDescription: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            // Stroke centre sits at 22/52 of the box (design source), leaving room for the badge border.
            let inset = side * 4 / 52

            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)
                    .padding(inset)

                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: fraction)

                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: side * 0.36, weight: .medium))
                        .foregroundStyle(symbolColor ?? color)
                }

                if showsCheck {
                    CheckBadge(diameter: side * 20 / 52)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: side * 2 / 52, y: side * 2 / 52)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? "Progress"))
        .accessibilityValue(valueDescription.map { Text($0) }
            ?? Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

extension ProgressRing {
    /// A nutrient's ring: its tint and symbol, amber near/over a limit, check badge when met.
    /// VoiceOver reads the nutrient name and "2,000 of 4,000 IU".
    init(nutrient: Nutrient, progress: GoalProgress, lineWidth: CGFloat = 5, showsSymbol: Bool = true) {
        let tint = nutrient.tint
        self.init(
            fraction: progress.ringFraction,
            color: progress.status.ringColor(tint: tint),
            trackColor: tint.trackColor,
            lineWidth: lineWidth,
            symbolName: showsSymbol ? nutrient.symbolName : nil,
            symbolColor: tint.color,
            showsCheck: progress.status == .met,
            label: nutrient.name,
            valueDescription: progress.progressText
        )
    }
}

/// 20pt green disc with a dark check and a card-coloured border, the same in light and dark (sizes scale with the ring).
private struct CheckBadge: View {
    let diameter: CGFloat

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: diameter * 0.5, weight: .heavy))
            .foregroundStyle(Theme.forest)
            .frame(width: diameter, height: diameter)
            .background(Theme.green, in: Circle())
            .overlay(Circle().strokeBorder(Theme.surfaceCard, lineWidth: max(1.5, diameter / 10)))
    }
}

// MARK: - Previews

private struct ProgressRingPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                ring(0.5, tint: .amber, symbol: "sun.max")
                ring(1, tint: .teal, symbol: "fish", check: true)
                ring(1, tint: .indigo, symbol: "pills", check: true)
                ring(0.6, tint: .blue, symbol: "drop")
            }
            HStack(spacing: 20) {
                // At most, nearing the limit → amber ring on the tint's track
                ProgressRing(fraction: 0.8, color: Theme.statusAmber, trackColor: NutrientTint.brown.trackColor,
                             symbolName: "cup.and.saucer", symbolColor: NutrientTint.brown.color)
                    .frame(width: 52, height: 52)
                ring(0.2, tint: .coral, symbol: "dumbbell")
                ring(0, tint: .pink, symbol: "heart")
                ring(0.75, tint: .green, symbol: nil)
            }
            HStack(spacing: 20) {
                ring(0.5, tint: .amber, symbol: "sun.max", size: 56)
                ring(0.7, tint: .teal, symbol: nil, size: 40)
                ProgressRing(fraction: 0.4, color: NutrientTint.blue.color, trackColor: NutrientTint.blue.trackColor, lineWidth: 6)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(Theme.Spacing.screenMargin)
        .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(Theme.Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }

    private func ring(_ fraction: Double, tint: NutrientTint, symbol: String?, check: Bool = false,
                      size: CGFloat = 52) -> some View {
        ProgressRing(fraction: fraction, color: tint.color, trackColor: tint.trackColor,
                     symbolName: symbol, showsCheck: check)
            .frame(width: size, height: size)
    }
}

#Preview("Light") {
    ProgressRingPreviewGallery()
}

#Preview("Dark") {
    ProgressRingPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility 3") {
    ProgressRingPreviewGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}
