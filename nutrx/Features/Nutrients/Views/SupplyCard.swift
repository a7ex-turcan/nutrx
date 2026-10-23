import SwiftData
import SwiftUI
import WidgetKit

/// The analytics Supply card (nutrx Pro; docs/pro/design/3-supply: analytics, cards). Pro, set: days left (amber
/// when low), "12 of 120 left", a gauge with the reminder tick, an explanation and Refilled. Pro, not set: Set up.
/// Free: the card with a PRO chip, which opens the paywall. Nothing while Pro is hidden.
struct SupplyCard: View {
    let nutrient: Nutrient

    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(NotificationRouter.self) private var router: NotificationRouter?

    /// Opened from a refill reminder: a forest outline (green in dark) and Refilled as the primary button.
    private var isFocused: Bool { router?.supplyNutrientID == nutrient.id }
    @State private var showSheet = false
    @State private var confirmRefill = false

    /// The analytics cards' inset (design source: 18pt).
    private let padding: CGFloat = 18

    var body: some View {
        if ProAccess.isStoreVisible {
            Group {
                if !(proAccess?.isPro ?? false) {
                    freeCard
                } else if let status = nutrient.supplyStatus() {
                    statusCard(status)
                } else {
                    setUpCard
                }
            }
            .sheet(isPresented: $showSheet) { SupplySheet(nutrient: nutrient) }
            .confirmationDialog("Refilled \(nutrient.name)?", isPresented: $confirmRefill, titleVisibility: .visible) {
                Button("Refilled") { refill() }
            } message: {
                Text("Starts the count again from a full bottle.")
            }
        }
    }

    // MARK: - States

    private var freeCard: some View {
        // The gate: for someone who turns out to be Pro once the first check lands, the card switches to theirs.
        ProGatedButton(action: {}) { _ in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Supply")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        ProBadge()
                    }
                    Text(SupplyText.teaser)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(padding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardStyle()
    }

    private var setUpCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Supply")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(SupplyText.teaser)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            Button("Set up") { showSheet = true }
                .font(.headline)
                .foregroundStyle(Theme.controlOnPrimary)
                .padding(.horizontal, 18)
                .frame(minHeight: Theme.minTouchTarget)
                .background(Theme.controlPrimary, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel("Set up supply")
        }
        .padding(padding)
        .cardStyle()
    }

    private func statusCard(_ status: SupplySchedule.Status) -> some View {
        let low = status.level == .low || status.level == .out
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Supply")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Edit") { showSheet = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.controlPrimary)
                    .frame(minHeight: Theme.minTouchTarget)
                    .accessibilityLabel("Edit supply")
            }

            let count = Text(markdown(SupplyText.servingsLine(status)))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        headline(status, low: low)
                        count
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        headline(status, low: low)
                        Spacer(minLength: 8)
                        count
                    }
                }
            }
            .accessibilityElement(children: .combine)

            // What it costs a month, once there's a price (#134).
            if let cost = nutrient.monthlySupplyCost() {
                Text(SupplyText.monthlyCost(cost))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            gauge(status, low: low)

            Text(markdown(SupplyText.explanation(status, unit: nutrient.unit)))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            // Low or out: Add to list beside Refilled, under it when they don't fit side by side (#134).
            if low, let line = nutrient.supplyListLine {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        refilledButton
                        addToListButton(line)
                    }
                    VStack(spacing: 10) {
                        refilledButton
                        addToListButton(line)
                    }
                }
            } else {
                refilledButton
            }
        }
        .padding(padding)
        .cardStyle()
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? Theme.green : Theme.forest, lineWidth: 3)
            }
        }
        .onDisappear {
            if isFocused { router?.supplyNutrientID = nil }
        }
    }

    @ViewBuilder
    private func headline(_ status: SupplySchedule.Status, low: Bool) -> some View {
        let color = low ? Theme.textAmberInk : Theme.textPrimary
        if status.level == .out {
            Text("Out of supply")
                .font(.title3.bold())
                .foregroundStyle(color)
        } else if let days = status.daysLeft {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(days.formatted())
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(days == 1 ? "day left" : "days left")
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(color)
        } else {
            // Not enough logging for an estimate yet: the count leads.
            EmptyView()
        }
    }

    private func gauge(_ status: SupplySchedule.Status, low: Bool) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceChip)
                Capsule()
                    .fill(low ? Theme.statusAmber : nutrient.tint.color)
                    .frame(width: max(status.fractionLeft > 0 ? 12 : 0, width * status.fractionLeft))
                if let threshold = status.thresholdFraction {
                    Rectangle()
                        .fill(Theme.textSecondary)
                        .frame(width: 2, height: 20)
                        .offset(x: min(width - 2, width * threshold))
                }
            }
        }
        .frame(height: 12)
        .accessibilityElement()
        .accessibilityLabel("Bottle")
        .accessibilityValue("\(Int((status.fractionLeft * 100).rounded())) percent left")
    }

    private func markdown(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string)) ?? AttributedString(string)
    }

    private var refilledButton: some View {
        Button {
            confirmRefill = true
        } label: {
            Label("Refilled", systemImage: "arrow.clockwise")
                .font(.headline)
                .foregroundStyle(isFocused ? Theme.controlOnPrimary : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background {
                    if isFocused {
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .fill(Theme.controlPrimary)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// The share sheet with the bottle's line, so it can go on a list in Reminders, Notes or Messages (#134): no
    /// permission, nothing stored.
    private func addToListButton(_ line: String) -> some View {
        ShareLink(item: line, preview: SharePreview(line)) {
            Label("Add to list", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func refill() {
        nutrient.refillSupply()
        try? modelContext.save()
        router?.supplyNutrientID = nil
        NotificationService.refreshAllNutrientReminders(context: modelContext)
        WidgetCenter.shared.reloadAllTimelines()  // the medium widget's "Running low" line
    }
}
