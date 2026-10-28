import SwiftUI

/// The reminders sheets' choice (nutrx Pro, #137, docs/pro/REMINDERS.md §3): at set times, or at my usual time, with
/// what the usual time is or how far it has learned underneath. The usual time is a `ProGatedButton`: free users see
/// the PRO chip and get the paywall. A real selection, so its tick is a symbol.
struct ReminderTimingSection: View {
    @Binding var atUsualTime: Bool
    var setTitle = "At set times"
    /// The footer: the usual time's state while it's chosen.
    let explanation: String?

    var body: some View {
        Section {
            Button {
                atUsualTime = false
            } label: {
                row(setTitle, selected: !atUsualTime, badge: false)
            }
            .buttonStyle(.plain)
            ProGatedButton(action: { atUsualTime = true }) { showsBadge in
                row("At my usual time", selected: atUsualTime, badge: showsBadge)
            }
            .buttonStyle(.plain)
        } footer: {
            if let explanation { Text(explanation) }
        }
    }

    private func row(_ title: String, selected: Bool, badge: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            if badge { ProBadge() }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
            }
        }
        .frame(minHeight: Theme.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
