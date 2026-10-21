import SwiftUI

/// First onboarding screen (DESIGN.md §5.8): full-bleed forest, the brand mark, "Track what you take. Nothing
/// else.", three benefits and Get started. Forest in both appearances, like the day-score card.
struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void

    /// The design's 38pt headline (Welcome.dc.html), scaling with Dynamic Type like `.largeTitle`.
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 38

    var body: some View {
        // Fixed layout when it fits (the spacer pushes the headline down, as in the mockup); scrolls at large text.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onGetStarted) {
                Text("Get started")
                    .font(.headline)
                    .foregroundStyle(Theme.textOnTint)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 12)
            // Opaque, so scrolled benefits (at large text sizes) don't show around the button.
            .background { Theme.forest.ignoresSafeArea() }
        }
        // The headline, benefits and button in one centred column on large screens; the forest still fills the
        // window (#151).
        .readableColumn(ownMargin: 28)
        .background {
            // An overlay, not a ZStack sibling: the 520pt rings would widen a ZStack past the screen and shift them.
            Theme.forest
                .overlay(alignment: .topTrailing) { rings }
                .ignoresSafeArea()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The app icon's mark, extracted from the icon artwork as a template image — not redrawn.
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 112)
                .foregroundStyle(Theme.green)
                .accessibilityLabel("nutrx")
                // The design puts the mark 120pt from the top of the frame; below the safe area (47–62pt) that's ~64.
                .padding(.top, 64)

            Spacer(minLength: 48)

            Text("\(Text("Track what you take.").foregroundStyle(Theme.onForestPrimary))\n\(Text("Nothing else.").foregroundStyle(Theme.greenSoft))")
                .font(.system(size: headlineSize, weight: .heavy))
                .tracking(-0.03 * headlineSize)  // the design's -0.03em
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 22) {
                benefit("lock", title: "Private by design",
                        detail: "No account, no servers. Your data stays on your devices and your iCloud.")
                benefit("slider.horizontal.3", title: "Your nutrients, your rules",
                        detail: "Any nutrient, any unit, any target — at least, at most or a range.")
                benefit("plus", title: "One tap to log",
                        detail: "From the app, a widget or your Apple Watch.")
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two rings echoing the day-score ring, decoration only (Welcome.dc.html): a faint full track with a brighter
    /// round-capped arc from 12 o'clock, in a 520pt box hanging 210pt off the trailing edge, 40pt from the top.
    private var rings: some View {
        ZStack {
            ring(radius: 230, arcLength: 900, trackOpacity: 0.10, arcOpacity: 0.35)
            ring(radius: 160, arcLength: 520, trackOpacity: 0.08, arcOpacity: 0.22)
        }
        .frame(width: 520, height: 520)
        .opacity(0.9)
        .offset(x: 210, y: 40)
        .accessibilityHidden(true)
    }

    /// One ring: `arcLength` points of a circle of `radius`, drawn with a 40pt stroke like the source SVG.
    private func ring(radius: CGFloat, arcLength: CGFloat, trackOpacity: Double, arcOpacity: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.green.opacity(trackOpacity), lineWidth: 40)
            Circle()
                .trim(from: 0, to: arcLength / (2 * .pi * radius))
                .stroke(Theme.green.opacity(arcOpacity), style: StrokeStyle(lineWidth: 40, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func benefit(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the 40pt tile doesn't grow with text
                .foregroundStyle(Theme.greenSoft)
                .frame(width: 40, height: 40)
                .background(Theme.onForestPrimary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.onForestPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.onForestSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    OnboardingWelcomeView {}
}

#Preview("Dark") {
    OnboardingWelcomeView {}
        .preferredColorScheme(.dark)
}

#Preview("Accessibility size") {
    OnboardingWelcomeView {}
        .dynamicTypeSize(.accessibility3)
}
