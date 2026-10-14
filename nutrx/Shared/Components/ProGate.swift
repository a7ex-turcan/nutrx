import SwiftUI

/// A Pro feature's entry point (docs/pro/PLAN.md, phase 3 "Gate"): for a Pro user it runs `action`; for a free
/// user it opens the paywall, and the label gets `showsBadge = true` so it can show the small PRO chip — never a
/// lock, a blur or a wall, and the free version of anything stays where it is.
struct ProGatedButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: (_ showsBadge: Bool) -> Label

    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @State private var showPaywall = false

    var body: some View {
        let isPro = proAccess?.isPro ?? false
        Button {
            Task {
                // Right after launch a Pro user isn't known yet: wait for the first check rather than show the
                // paywall to someone who already paid.
                if let proAccess, !proAccess.hasCheckedEntitlements {
                    await proAccess.refreshEntitlement()
                }
                if proAccess?.isPro ?? false { action() } else { showPaywall = true }
            }
        } label: {
            label(!isPro)
        }
        .accessibilityHint(isPro ? "" : "Part of nutrx Pro. Opens what Pro includes.")
        .proPaywall(isPresented: $showPaywall)
    }
}

#Preview("Free") {
    ProGatedButton(action: {}) { showsBadge in
        HStack {
            Text("Scan a label").font(.headline)
            if showsBadge { ProBadge() }
        }
    }
    .environment(ProAccess())
}
