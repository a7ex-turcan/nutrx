import SwiftUI

/// First onboarding screen (DESIGN.md §5.8): full-bleed forest, the brand mark, "Track what you take. Nothing
/// else.", three benefits and Get started. Forest in both appearances, like the day-score card.
struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void

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
            .padding(.bottom, 12)
        }
        .background {
            ZStack(alignment: .topTrailing) {
                Theme.forest
                rings
            }
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
                .padding(.top, 40)

            Spacer(minLength: 48)

            Text("\(Text("Track what you take.").foregroundStyle(Theme.onForestPrimary))\n\(Text("Nothing else.").foregroundStyle(Theme.greenSoft))")
                .font(.system(.largeTitle, weight: .heavy))
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

    /// Two open rings echoing the day-score ring — decoration only.
    private var rings: some View {
        ZStack {
            Circle()
                .trim(from: 0.06, to: 0.78)
                .stroke(Theme.green.opacity(0.14), style: StrokeStyle(lineWidth: 40, lineCap: .round))
                .frame(width: 500, height: 500)
            Circle()
                .trim(from: 0.04, to: 0.74)
                .stroke(Theme.green.opacity(0.10), style: StrokeStyle(lineWidth: 40, lineCap: .round))
                .frame(width: 360, height: 360)
        }
        .rotationEffect(.degrees(-80))
        .offset(x: 220, y: 40)
        .accessibilityHidden(true)
    }

    private func benefit(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
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
