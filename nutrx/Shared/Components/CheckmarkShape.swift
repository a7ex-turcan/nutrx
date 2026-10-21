import SwiftUI

/// A tick drawn as a shape, for decorative badges: a checkmark SF Symbol stayed in the accessibility tree as
/// "Selected" even when hidden (#77), and a shape is never an element. Stroke it with round caps and joins.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// A dark tick on a green disc, the "done" badge (the stack done badge, the Logged and Exported strips, the Pro card):
/// drawn, so VoiceOver never reads it as "Selected" (#203). The tick scales with the disc.
struct TickDisc: View {
    var diameter: CGFloat = 28

    var body: some View {
        CheckmarkShape()
            .stroke(Theme.forest, style: StrokeStyle(lineWidth: max(1.8, diameter * 0.085), lineCap: .round,
                                                     lineJoin: .round))
            .frame(width: diameter * 0.43, height: diameter * 0.32)
            .frame(width: diameter, height: diameter)
            .background(Theme.green, in: Circle())
            .accessibilityHidden(true)
    }
}
