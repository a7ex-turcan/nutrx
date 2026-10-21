import StoreKit
import SwiftUI

/// Settings → nutrx Pro for a Pro user (docs/pro/design/2-paywall: pro-screen): "You're on Pro" with the plan,
/// what's included, Manage subscription (subscriptions only) and Restore purchases.
struct ProStatusView: View {
    @Environment(ProAccess.self) private var proAccess
    @State private var showManage = false
    @State private var restoring = false
    @State private var restoreFailed = false

    var body: some View {
        List {
            Section {
                card
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(ProFeature.listed) { feature in
                    HStack(spacing: 14) {
                        NutrientIconTile(tint: feature.tint, symbolName: feature.symbolName, size: 32)
                        Text(feature.shortTitle)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(minHeight: Theme.minTouchTarget)
                }
            } header: {
                Text("Included")
                    .textCase(.uppercase)
            }
            .listRowBackground(Theme.surfaceCard)

            Section {
                if proAccess.entitlement?.plan != .lifetime && proAccess.entitlement?.isFamilyShared == false {
                    Button("Manage subscription") { showManage = true }
                        .foregroundStyle(Theme.controlPrimary)
                }
                Button(restoring ? "Restoring…" : "Restore purchases") {
                    restoring = true
                    Task {
                        defer { restoring = false }
                        do { try await proAccess.restore() } catch StoreKitError.userCancelled {} catch { restoreFailed = true }
                    }
                }
                .foregroundStyle(Theme.controlPrimary)
                .disabled(restoring)
            } footer: {
                Text("Thanks for supporting an app with no ads and no servers.")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .readableColumn(ownMargin: 20)
        .background(Theme.surfaceGround)
        .navigationTitle("nutrx Pro")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManage, subscriptionGroupID: ProAccess.ProductID.subscriptionGroupID)
        .onChange(of: showManage) { _, showing in
            if !showing { Task { await proAccess.refreshEntitlement() } }
        }
        .alert("Couldn't restore", isPresented: $restoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProWordmark()
            Text("You're on Pro")
                .font(.title3.bold())
                .foregroundStyle(Theme.onForestPrimary)
            if let entitlement = proAccess.entitlement {
                Text(ProText.longStatus(entitlement))
                    .font(.subheadline)
                    .foregroundStyle(Theme.onForestSecondary)
                if entitlement.isFamilyShared {
                    Text("Shared with you through Family Sharing")
                        .font(.subheadline)
                        .foregroundStyle(Theme.onForestSecondary)
                }
            }
        }
        .padding(20)
        .padding(.trailing, 40)  // keeps the plan line clear of the ring's green arc
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            ProRingMotif(lineWidth: 22)
                .frame(width: 170, height: 170)
                .offset(x: 35, y: -55)
        }
        .background(Theme.forest)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Pro screen") {
    NavigationStack {
        ProStatusView()
    }
    .environment(ProAccess())
}
