import StoreKit
import SwiftUI

/// The nutrx Pro paywall (docs/pro/design/2-paywall: paywall, paywall-lifetime), a full-height sheet: a forest
/// header with the wordmark, what Pro adds, the three plans as radio cards (lifetime under "or pay once"), the
/// buy button with its price terms, and Restore · Terms · Privacy. After a purchase the sheet turns into the
/// welcome (`ProWelcomeView`): at half height on iPhone, full height at accessibility sizes and on large widths.
struct PaywallView: View {
    @Environment(ProAccess.self) private var proAccess
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widthClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// StoreKit's purchase with this sheet's UI context, so the confirmation shows over the paywall: Apple's advice
    /// for SwiftUI, rather than `Product.purchase()` choosing a window itself (#170).
    @Environment(\.purchase) private var purchase

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

    private var halvesWelcome: Bool {
        welcomed && !dynamicTypeSize.isAccessibilitySize && widthClass == .compact
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
        // The welcome sheet is half height on iPhone, or full height at accessibility sizes, where its text doesn't
        // fit. From regular widths the page sheet keeps its height, the welcome centred in it: a medium detent shrank
        // it from the bottom up, and the welcome sat in the lower half of the iPad's screen (#206).
        .presentationDetents(halvesWelcome ? [.medium] : [.large])
        .presentationDragIndicator(welcomed && widthClass == .compact ? .visible : .hidden)
        // On iPad a page sheet, taller than the default form sheet, so more of the plans are in view (#205); sizing
        // doesn't change a sheet on iPhone.
        .presentationSizing(.page)
        .task { await loadStore() }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text("OK")))
        }
    }

    /// From xLarge up (below accessibility sizes), and on large screens at any size, the whole pinned footer hid the
    /// plans behind it (#189, #205): only the button stays pinned, with a line naming the selected plan that scrolls
    /// to the plans; the terms and links scroll after them. At accessibility sizes everything scrolls (pinned, it
    /// covered a third of the screen).
    private enum FooterLayout { case pinned, buttonPinned, scrolls }

    private var footerLayout: FooterLayout {
        if dynamicTypeSize.isAccessibilitySize { return .scrolls }
        // On large screens the paywall is a sheet shorter than the screen (a landscape iPhone is short too), and with
        // the whole footer pinned the plans started below the fold even at the default size (#205).
        return dynamicTypeSize >= .xLarge || widthClass != .compact ? .buttonPinned : .pinned
    }

    private var paywall: some View {
        let layout = footerLayout
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 22) {
                        features
                        plans
                            .id(Self.plansID)
                        switch layout {
                        case .scrolls: VStack(spacing: 10) { purchaseButton; purchaseDetails }
                        case .buttonPinned: purchaseDetails
                        case .pinned: EmptyView()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                    // In the iPad's 928 pt page sheet: a centred 640 pt column (LAYOUT.md, Pro screens), so a price
                    // stays near its plan; the forest header still spans the sheet.
                    .frame(maxWidth: ReadableColumn.maxWidth)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                if layout != .scrolls {
                    Group {
                        if layout == .pinned {
                            VStack(spacing: 10) { purchaseButton; purchaseDetails }
                        } else {
                            VStack(spacing: 8) {
                                planSummary {
                                    withAnimation(.unlessReduceMotion(reduceMotion, .default)) {
                                        proxy.scrollTo(Self.plansID, anchor: .top)
                                    }
                                }
                                purchaseButton
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 10)
                    .frame(maxWidth: ReadableColumn.maxWidth)
                    .frame(maxWidth: .infinity)
                    .background(Theme.surfaceGround)
                    // With only the button pinned, the plans scroll under it: a hairline marks the edge.
                    .overlay(alignment: .top) {
                        if layout == .buttonPinned {
                            Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        }
                    }
                }
            }
        }
        .background(Theme.surfaceGround)
    }

    private static let plansID = "plans"

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
        // Lined up with the 640 pt column below in a wide sheet (its screen margins are narrower than these 22);
        // the forest and the rings still span the sheet.
        .frame(maxWidth: ReadableColumn.maxWidth + 2 * (22 - Theme.Spacing.screenMargin), alignment: .leading)
        .frame(maxWidth: .infinity)
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
        // (docs/pro/design/2-paywall: no-apple-intelligence). Related features share a row (`ProFeatureGroup`).
        let reading = ScanText.Reading.current
        let device = UIDevice.current.model
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(ProFeatureGroup.listed) { group in
                HStack(spacing: 14) {
                    NutrientIconTile(tint: group.tint, symbolName: group.symbolName, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(group.subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        if let note = ProText.appleIntelligenceRowNote(group, reading: reading, device: device) {
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
                .accessibilityLabel("Loading plans")
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
                // At accessibility sizes the parts stack under the radio, so nothing breaks mid-word (#161).
                let large = dynamicTypeSize.isAccessibilitySize
                HStack(alignment: large ? .top : .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? selectedBorder : Theme.controlGhostBorder, lineWidth: isSelected ? 6 : 2)
                    }
                    .frame(width: 22, height: 22)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .padding(.top, large ? 6 : 0)
                    VStack(alignment: .leading, spacing: large ? 6 : 2) {
                        // The badge sits beside the name when both fit whole, and under it otherwise (always at
                        // accessibility sizes): squeezed beside it, it broke over two lines at xxLarge on an iPhone SE.
                        ViewThatFits(in: .horizontal) {
                            if !large {
                                HStack(spacing: 8) { planTitle(plan) }
                            }
                            VStack(alignment: .leading, spacing: 6) { planTitle(plan) }
                        }
                        Text(ProText.planSubtitle(plan, monthlyEquivalent: plan == .yearly
                                                  ? ProText.monthlyEquivalent(ofYearly: product.price, format: product.priceFormatStyle)
                                                  : nil))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        if large {
                            price(product)
                        }
                    }
                    if !large {
                        Spacer(minLength: 8)
                        price(product)
                    }
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

    /// A plan's name, and "1 WEEK FREE" while the trial applies; the caller puts them side by side or stacked.
    @ViewBuilder
    private func planTitle(_ plan: ProAccess.Plan) -> some View {
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
                .fixedSize()
        }
    }

    private func price(_ product: Product) -> some View {
        Text(product.displayPrice)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
    }

    // MARK: - Buy

    private var purchaseButton: some View {
        let product = proAccess.product(selected)
        return Button {
            if let product { buy(product) }
        } label: {
            ZStack {
                if purchasing {
                    // Hidden: the button's label says "Purchasing…"; the spinner's own value read as "1" (#94).
                    ProgressView().tint(Theme.controlOnPrimary).accessibilityHidden(true)
                } else {
                    Text(ProText.primaryTitle(plan: selected, trialEligible: trialEligible))
                        .multilineTextAlignment(.center)  // "Start free / week" at the largest sizes (#161)
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
        // While purchasing the label is only a spinner, which VoiceOver read as nothing (#94).
        .accessibilityLabel(ProText.primaryAccessibilityLabel(plan: selected, trialEligible: trialEligible,
                                                              purchasing: purchasing))
    }

    /// The terms, "Everything you use today stays free." and Restore · Terms · Privacy.
    private var purchaseDetails: some View {
        let product = proAccess.product(selected)
        return VStack(spacing: 10) {
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

    /// "Yearly · $14.99 a year · 1 week free" with "Plans", pinned over the button when the plans can be out of
    /// view; tapping it scrolls to them.
    @ViewBuilder
    private func planSummary(showPlans: @escaping () -> Void) -> some View {
        if let product = proAccess.product(selected) {
            let summary = ProText.planSummary(plan: selected, price: product.displayPrice, trialEligible: trialEligible)
            Button(action: showPlans) {
                // No stack spacing: the spacer's minimum is the gap, and the summary needs every point at xLarge.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Text("Plans")
                        Image(systemName: "chevron.up").imageScale(.small)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textGreenInk)
                    .fixedSize()
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary)
            .accessibilityHint("Shows the plans")
        }
    }

    @ViewBuilder
    private var footerLinks: some View {
        Button(restoring ? "Restoring…" : "Restore purchases") { restore() }
            .disabled(restoring || purchasing)
            .multilineTextAlignment(.center)  // its two lines centred when it wraps (#161)
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
                switch await proAccess.complete(try await purchase(product)) {
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

// Inline rather than in a sheet: preview snapshots don't capture presented sheets. Shows the button pinned with
// the plan summary above it (#189).
#Preview("Paywall, xLarge") {
    PaywallView()
        .environment(ProAccess())
        .dynamicTypeSize(.xLarge)
}

// The large-screen branch (#205) without an iPad: only the button pinned, the plan summary above it, a 640 pt column.
#Preview("Paywall, large screen") {
    PaywallView()
        .environment(ProAccess())
        .environment(\.widthClass, .regular)
}
