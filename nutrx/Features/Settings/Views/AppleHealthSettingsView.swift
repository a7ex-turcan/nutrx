import SwiftUI

/// Settings → Apple Health (nutrx Pro, docs/pro/design/6-health-trends: settings): trends on or off, what's read and
/// whether nutrx finds any of it, where to change access, the privacy note, and Disconnect. HealthKit never tells an
/// app whether read access was granted, so a type shows "Data found" or "No data yet" rather than "Allowed".
struct AppleHealthSettingsView: View {
    @State private var isConnected = HealthReader.isConnected
    @State private var showIntro = false
    @State private var found: (sleep: Bool, workouts: Bool, energy: Bool)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap + 8) {
                Toggle(isOn: Binding(
                    get: { isConnected },
                    set: { on in
                        if on { showIntro = true } else { disconnect() }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trends with Apple Health").foregroundStyle(Theme.textPrimary)
                        Text(isConnected ? "Connected" : "Off")
                            .font(.subheadline)
                            .foregroundStyle(isConnected ? Theme.textGreenInk : Theme.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.cardPadding)
                .frame(minHeight: 64)
                .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HealthTypesCard(title: "What nutrx reads", values: values)
                    Text("Change access in the Health app under Sharing › Apps › nutrx.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                }

                HealthPrivacyNote(text: "Read only. Health data stays on this \(UIDevice.current.model) — it's never saved to iCloud or synced to your other devices.")

                if isConnected {
                    Button(role: .destructive) { disconnect() } label: {
                        Text("Disconnect Apple Health")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.vertical, 8)
        }
        .background(Theme.surfaceGround)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showIntro) {
            HealthIntroView { isConnected = true }
        }
        .task(id: isConnected) {
            found = isConnected ? await HealthReader.typesWithData() : nil
        }
    }

    private var values: [String]? {
        guard isConnected, let found else { return nil }
        return [found.sleep, found.workouts, found.energy].map { $0 ? "Data found" : "No data yet" }
    }

    private func disconnect() {
        HealthReader.disconnect()
        isConnected = false
    }
}

#Preview {
    NavigationStack { AppleHealthSettingsView() }
}
