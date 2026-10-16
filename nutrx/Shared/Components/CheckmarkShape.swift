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
