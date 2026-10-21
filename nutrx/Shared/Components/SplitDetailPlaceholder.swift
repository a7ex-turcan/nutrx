import SwiftUI

/// The empty detail pane of a large-screen split view (#153, #154): an icon tile, a title and one line, centred.
struct SplitDetailPlaceholder: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                .frame(width: 64, height: 64)
                .background(Theme.surfaceChip, in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile,
                                                                   style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

#Preview {
    SplitDetailPlaceholder(systemImage: "calendar", title: "Pick a day",
                           message: "Choose a day in the calendar to see which goals you met and what you logged.")
}
