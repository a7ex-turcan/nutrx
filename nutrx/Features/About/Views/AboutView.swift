import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon & name
                VStack(spacing: 8) {
                    // The app icon's mark (BrandMark), on forest like the icon.
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52)
                        .foregroundStyle(Theme.green)
                        .frame(width: 88, height: 88)
                        .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.appIcon, style: .continuous))
                        .accessibilityHidden(true)

                    Text("nutrx")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 20)

                // Philosophy
                VStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Privacy First", systemImage: "lock.shield")
                            .font(.headline)

                        Text("nutrx has no accounts, no servers and no tracking. Your data lives on your devices and your iCloud, and it belongs to you.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.cardPadding + 2)
                .cardStyle()

                VStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Simple by Design", systemImage: "sparkles")
                            .font(.headline)

                        Text("Track the nutrients that matter to you. No calorie counting, no food databases, no complexity. Just straightforward daily tracking.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.cardPadding + 2)
                .cardStyle()

                VStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How It Works", systemImage: "questionmark.circle")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            bulletPoint("Define your own nutrients and daily targets")
                            bulletPoint("Log intake with quick taps or custom amounts")
                            bulletPoint("Review your history to stay consistent")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.cardPadding + 2)
                .cardStyle()

                // Footer
                VStack(spacing: 4) {
                    Text("Made with care")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)

                    Text("nutrx labs")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
        .background(Theme.surfaceGround)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    NavigationStack {
        AboutView()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
    }
}
