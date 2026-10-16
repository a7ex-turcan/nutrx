import SwiftUI

/// "Welcome to nutrx Pro" (docs/pro/design/2-paywall: success), shown in the paywall's sheet at medium height
/// once a purchase or restore unlocks Pro: the ring badge, what's on now, the plan line and Continue.
struct ProWelcomeView: View {
    let onContinue: () -> Void

    @Environment(ProAccess.self) private var proAccess

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 12)
            ZStack {
                Circle().fill(Theme.forest)
                SegmentedRingMark()
                    .frame(width: 84, height: 84)
                // Drawn, not an SF Symbol: a checkmark image stayed in the accessibility tree as "Selected" even
                // hidden (#77), and a shape is never an element.
                CheckmarkShape()
                    .stroke(Theme.greenSoft, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 20)
            }
            .frame(width: 112, height: 112)
            .accessibilityHidden(true)
            Text("Welcome to nutrx Pro")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(ProText.welcome(ProFeature.listed))
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let entitlement = proAccess.entitlement {
                Text(ProText.longStatus(entitlement))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.controlPrimary,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceGround)
    }
}

/// Six rounded green dashes in a ring, as in the welcome badge.
private struct SegmentedRingMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                Circle()
                    .trim(from: CGFloat(index) / 6 + 0.02, to: CGFloat(index + 1) / 6 - 0.02)
                    .stroke(Theme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
    }
}

#Preview("Welcome") {
    ProWelcomeView {}
        .environment(ProAccess())
}
