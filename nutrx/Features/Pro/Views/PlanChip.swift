import SwiftUI

/// The plan chip on the leading side of Today's bar (#101): "Free" (opens the paywall) or "PRO" (opens "Enjoy nutrx
/// Pro"). Nothing until the first entitlement check, so someone who paid never sees "Free" flash by. Today leaves it
/// out at accessibility text sizes (Pro is still in Settings).
///
/// The chip only asks for its sheets: Today owns them (`planChipSheets`), like the profile menu and History's
/// "Your data" menu do. Hung from the chip, inside a toolbar item, a sheet's state lived in that item, so a rebuilt
/// item would close it: the suspected cause of the paywall closing on a first purchase tap (#170).
struct PlanChip: View {
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showPaywall: Bool
    @Binding var showEnjoy: Bool

    var body: some View {
        if let proAccess, ProAccess.isStoreVisible, proAccess.hasCheckedEntitlements {
            let isPro = proAccess.isPro
            Button {
                if isPro { showEnjoy = true } else { showPaywall = true }
            } label: {
                Text(ProText.planChipTitle(isPro: isPro))
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(isPro ? (colorScheme == .dark ? Theme.forest : Theme.greenSoft) : Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isPro ? (colorScheme == .dark ? Theme.green : Theme.forest) : Theme.surfaceChip,
                                in: Capsule())
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // a badge, like the PRO chip
                    // Its own width: the bar otherwise gives it an icon's 44pt square and "Free" wrapped.
                    .fixedSize()
                    .frame(minHeight: Theme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ProText.planChipAccessibilityLabel(isPro: isPro))
        }
    }
}

extension View {
    /// The plan chip's paywall and "Enjoy nutrx Pro" sheets, attached outside the toolbar (see `PlanChip`).
    func planChipSheets(showPaywall: Binding<Bool>, showEnjoy: Binding<Bool>) -> some View {
        proPaywall(isPresented: showPaywall)
            .sheet(isPresented: showEnjoy) {
                NavigationStack {
                    EnjoyProView()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

/// "Enjoy nutrx Pro" (#101): the plan, what's on, and the Pro screen (manage, restore).
private struct EnjoyProView: View {
    @Environment(ProAccess.self) private var proAccess
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    ProWordmark(size: 24)
                    Text("Enjoy nutrx Pro")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.onForestPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let entitlement = proAccess.entitlement {
                        Text(ProText.shortStatus(entitlement))
                            .font(.subheadline)
                            .foregroundStyle(Theme.onForestSecondary)
                    }
                }
                .padding(Theme.Spacing.cardPadding + 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(ProFeature.listed) { feature in
                    HStack(spacing: 14) {
                        NutrientIconTile(tint: feature.tint, symbolName: feature.symbolName, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.shortTitle)
                                .foregroundStyle(Theme.textPrimary)
                            Text(feature.subtitle)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("On for you")
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                NavigationLink("Manage nutrx Pro") {
                    ProStatusView()
                }
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 4, for: .scrollContent)  // the card right under the bar, not a section's gap below it
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#if DEBUG
#Preview("Enjoy nutrx Pro") {
    NavigationStack {
        EnjoyProView()
    }
    .environment(ProAccess.previewPro())
}
#endif
