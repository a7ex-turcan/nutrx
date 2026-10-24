import SwiftUI

/// Done for a pinned panel above the keyboard, right-aligned: hides the keyboard. Onboarding's goal fields (#19) and
/// the log sheet (#274) put it there rather than in a keyboard toolbar, whose floating bar covered their buttons.
struct KeyboardDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                .frame(minWidth: Theme.minTouchTarget, minHeight: Theme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityHint("Hides the keyboard")
    }
}
