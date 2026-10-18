import StoreKit
import SwiftUI

/// The nutrx Pro paywall (docs/pro/design/2-paywall: paywall, paywall-lifetime), a full-height sheet: a forest
/// header with the wordmark, what Pro adds, the three plans as radio cards (lifetime under "or pay once"), the
/// buy button with its price terms, and Restore · Terms · Privacy. After a purchase the sheet turns into the
/// welcome (`ProWelcomeView`) at medium height.
struct PaywallView: View {
    @Environment(ProAccess.self) private var proAccess
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selected: ProAccess.Plan = .yearly
    @State private var trialEligible = false
    @State private var loading = true
    @State private var purchasing = false
    @State private var restoring = false
    @State private var welcomed = false
    @State private var message: Message?

    private struct Message: Identifiable {
        let title: String
        let body: String
        var id: String { title + body }
    }

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://nutrx.nutrx-labs.com/privacy.html")!

    var body: some View {
        Group {
            if welcomed {
                ProWelcomeView { dismiss() }
            } else {
                paywall
            }
        }
        // The welcome sheet is half height, or full height at accessibility sizes, where its text doesn't fit.
        .presentationDetents(welcomed && !dynamicTypeSize.isAccessibilitySize ? [.medium] : [.large])
        .presentationDragIndicator(welcomed ? .visible : .hidden)
        .task { await loadStore() }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text("OK")))
        }
    }

    private var paywall: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(spacing: 22) {
                    features
                    plans
                    if dynamicTypeSize.isAccessibilitySize {
                        purchaseFooter
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        // At accessibility sizes the button scrolls with the content (pinned, it covered a third of the screen).
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                purchaseFooter
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 10)
                    .background(Theme.surfaceGround)
            }
        }
        .background(Theme.surfaceGround)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ProWordmark()
                    .padding(.top, 6)
                Spacer(minLength: 12)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.onForestPrimary)
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                        .background(Theme.onForestTrack, in: Circle())
                }
                .buttonStyle(.plain)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel("Close")
            }
            Text("More around your tracking. Private like everything else — it all runs on your \(UIDevice.current.model).")
                .font(.body)
                .foregroundStyle(Theme.onForestSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 64)  // clear of the rings, as in the design (three lines)
        }
        .padding(.top, 26 + 20)  // the sheet's top inset, then the design's 26
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            // Centred about 50pt in from the right and 40pt down, so the green arc lands near the header's bottom.
            ProRingMotif(lineWidth: 26)
                .frame(width: 190, height: 190)
                .offset(x: 45, y: -55)
        }
        .background(Theme.forest)
        .clipped()
    }

    // MARK: - Features

    private var features: some View {
        // Without Apple Intelligence the features still work, more simply: say so where it applies
        // (docs/pro/design/2-paywall: no-apple-intelligence).
        let reading = ScanText.Reading.current
        let device = UIDevice.current.model
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(ProFeature.listed) { feature in
                HStack(spacing: 14) {
                    NutrientIconTile(tint: feature.tint, symbolName: feature.symbolName, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(feature.subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        if let note = ProText.appleIntelligenceRowNote(feature, reading: reading, device: device) {
                            Label(note, systemImage: "info.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 46)
                .accessibilityElement(children: .combine)
            }
            if reading.mentionsAppleIntelligence, let note = ProText.appleIntelligenceNote(ProFeature.listed, device: device) {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if proAccess.products.isEmpty {
            VStack(spacing: 10) {
                Text("Couldn't reach the App Store")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Try again") {
                    loading = true
                    Task { await loadStore() }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.controlPrimary)
                .frame(minHeight: Theme.minTouchTarget)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            VStack(spacing: 12) {
                planCard(.yearly)
                planCard(.monthly)
                HStack(spacing: 12) {
                    Rectangle().fill(Theme.controlGhostBorder).frame(height: 1)
                    Text("or pay once")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                    Rectangle().fill(Theme.controlGhostBorder).frame(height: 1)
                }
                .padding(.vertical, 2)
                .accessibilityHidden(true)
                planCard(.lifetime)
            }
        }
    }

    @ViewBuilder
    private func planCard(_ plan: ProAccess.Plan) -> some View {
        if let product = proAccess.product(plan) {
            let isSelected = selected == plan
            let selectedBorder = colorScheme == .dark ? Theme.green : Theme.forest
            Button {
                selected = plan
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? selectedBorder : Theme.controlGhostBorder, lineWidth: isSelected ? 6 : 2)
                    }
                    .frame(width: 22, height: 22)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(ProText.planTitle(plan))
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            if plan == .yearly && trialEligible {
                                Text("1 WEEK FREE")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.textGreenInk)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.green.opacity(0.16),
                                                in: RoundedRectangle(cornerRadius: Theme.Radius.tag, style: .continuous))
                            }
                        }
                        Text(ProText.planSubtitle(plan, monthlyEquivalent: plan == .yearly
                                                  ? ProText.monthlyEquivalent(ofYearly: product.price, format: product.priceFormatStyle)
                                                  : nil))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(product.displayPrice)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Theme.surfaceCard,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .strokeBorder(selectedBorder, lineWidth: 2)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        }
    }

    // MARK: - Buy

    private var purchaseFooter: some View {
        let product = proAccess.product(selected)
        return VStack(spacing: 10) {
            Button {
                if let product { buy(product) }
            } label: {
                ZStack {
                    if purchasing {
                        ProgressView().tint(Theme.controlOnPrimary)
                    } else {
                        Text(ProText.primaryTitle(plan: selected, trialEligible: trialEligible))
                    }
                }
                .font(.headline)
                .foregroundStyle(Theme.controlOnPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.controlPrimary,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .opacity(product == nil ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(product == nil || purchasing || restoring)

            VStack(spacing: 4) {
                if let product {
                    Text(ProText.terms(plan: selected, price: product.displayPrice, trialEligible: trialEligible))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Everything you use today stays free.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textGreenInk)
            }
            .multilineTextAlignment(.center)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { footerLinks }
                VStack(spacing: 0) { footerLinks }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var footerLinks: some View {
        Button(restoring ? "Restoring…" : "Restore purchases") { restore() }
            .disabled(restoring || purchasing)
            .frame(minHeight: 36)
        Button("Terms") { openURL(Self.termsURL) }
            .frame(minHeight: 36)
            .accessibilityHint("Opens the Terms of Use")
        Button("Privacy") { openURL(Self.privacyURL) }
            .frame(minHeight: 36)
            .accessibilityHint("Opens the privacy policy")
    }

    // MARK: - Actions

    /// Products and trial eligibility together, so the button and terms always match what a purchase will do.
    private func loadStore() async {
        await proAccess.loadProducts()
        trialEligible = await proAccess.product(.yearly)?.subscription?.isEligibleForIntroOffer ?? false
        loading = false
    }

    private func buy(_ product: Product) {
        purchasing = true
        Task {
            defer { purchasing = false }
            do {
                switch try await proAccess.purchase(product) {
                case .purchased:
                    withAnimation(.unlessReduceMotion(reduceMotion, .default)) { welcomed = true }
                case .pending:
                    message = Message(title: "Waiting for approval",
                                      body: "Pro turns on as soon as the purchase is approved.")
                case .cancelled:
                    break
                case .failed:
                    message = Message(title: "Couldn't complete the purchase",
                                      body: "The App Store couldn't confirm it on this device. Try Restore purchases in a moment.")
                }
            } catch StoreKitError.userCancelled {
                // Backed out of the App Store's own sheet: nothing to say.
            } catch {
                message = Message(title: "Couldn't complete the purchase", body: error.localizedDescription)
            }
        }
    }

    private func restore() {
        restoring = true
        Task {
            defer { restoring = false }
            do {
                try await proAccess.restore()
                if proAccess.isPro {
                    withAnimation(.unlessReduceMotion(reduceMotion, .default)) { welcomed = true }
                } else {
                    message = Message(title: "Nothing to restore",
                                      body: "No nutrx Pro purchase was found for this Apple Account.")
                }
            } catch StoreKitError.userCancelled {
                // Cancelled the App Store sign-in: nothing to say.
            } catch {
                message = Message(title: "Couldn't restore", body: error.localizedDescription)
            }
        }
    }
}

extension View {
    /// Presents the nutrx Pro paywall. Every Pro entry point goes through this.
    func proPaywall(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView()
        }
    }
}

#Preview("Paywall") {
    Color.clear
        .sheet(isPresented: .constant(true)) { PaywallView() }
        .environment(ProAccess())
}
