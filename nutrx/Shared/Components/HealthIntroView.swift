import SwiftUI

/// Before the system's Health permission sheet (docs/pro/design/6-health-trends: intro): what nutrx reads, that it's
/// read only and stays on the device. Continue asks HealthKit; Not now closes it.
struct HealthIntroView: View {
    let onConnected: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var connecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(NutrientTint.coral.tileGlyph)
                    .frame(width: 64, height: 64)
                    .background(NutrientTint.coral.tileBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
                    .padding(.top, 24)
                Text("See your intake next to your sleep and workouts")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("nutrx compares what you log with a few things from Apple Health and shows patterns it finds. Patterns, not causes — and never advice.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HealthTypesCard(title: "nutrx will read", values: nil)
                HealthPrivacyNote(text: "Read only — nutrx never writes to Apple Health. Health data stays on this \(UIDevice.current.model): it's never saved to iCloud and never leaves the device.")
            }
            .padding(.horizontal, Theme.Spacing.screenMargin + 4)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    connecting = true
                    Task {
                        let connected = await HealthReader.connect()
                        connecting = false
                        if connected { onConnected() }
                        dismiss()
                    }
                } label: {
                    Group {
                        if connecting { ProgressView().tint(Theme.controlOnPrimary) } else { Text("Continue") }
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.controlPrimary, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(connecting)
                Button("Not now") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget)
            }
            .padding(.horizontal, Theme.Spacing.screenMargin + 4)
            .padding(.vertical, 8)
            .background(Theme.surfaceGround)
        }
        .background(Theme.surfaceGround)
        .presentationDragIndicator(.visible)
    }
}

/// Sleep, Workouts and Active energy with their tiles; optionally each with a value ("Data found").
struct HealthTypesCard: View {
    let title: String
    /// Per type, in order: sleep, workouts, active energy.
    let values: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                row("Sleep", symbol: "moon.fill", color: Theme.SettingsTile.blue, value: values?[0])
                Divider().overlay(Theme.lineHairline).padding(.leading, 60)
                row("Workouts", symbol: "figure.run", color: Theme.SettingsTile.green, value: values?[1])
                Divider().overlay(Theme.lineHairline).padding(.leading, 60)
                row("Active energy", symbol: "flame.fill", color: Theme.SettingsTile.coral, value: values?[2])
            }
            .background(Theme.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    private func row(_ name: String, symbol: String, color: Color, value: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: Theme.Radius.settingsTile, style: .continuous))
                .accessibilityHidden(true)
            Text(name).foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            if let value { Text(value).foregroundStyle(Theme.textSecondary) }
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(name), \($0)" } ?? name)
    }
}

/// The green lock note: read only, stays on the device.
struct HealthPrivacyNote: View {
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline).foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock").foregroundStyle(Theme.textGreenInk)
        }
        .padding(Theme.Spacing.cardPadding + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.greenSoft.opacity(0.35), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}
