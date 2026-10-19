import SwiftUI

/// Toolbar confirm buttons (Add, Save): Liquid Glass prominent while they can be used, plain glass while they can't.
/// A disabled `.glassProminent` keeps bright white text in dark mode, so it read as tappable (#73).
private struct ConfirmButtonStyle: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass).disabled(true)
        }
    }
}

extension View {
    /// Styles a toolbar confirm button and disables it when `enabled` is false.
    func confirmButton(enabled: Bool) -> some View {
        modifier(ConfirmButtonStyle(isEnabled: enabled))
    }
}
