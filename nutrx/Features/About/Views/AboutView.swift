import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon & name
                VStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)

                    Text("nutrx")
                        .font(.largeTitle.weight(.bold))

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Philosophy
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Privacy First", systemImage: "lock.shield")
                            .font(.headline)

                        Text("All your data stays on your device. nutrx has no accounts, no servers, and no tracking. Your health data belongs to you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Simple by Design", systemImage: "sparkles")
                            .font(.headline)

                        Text("Track the nutrients that matter to you. No calorie counting, no food databases, no complexity. Just straightforward daily tracking.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox {
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
                    .padding(.vertical, 4)
                }

                // Footer
                VStack(spacing: 4) {
                    Text("Made with care")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("nutrx labs")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
