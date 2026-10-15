import SwiftData
import SwiftUI

/// The weekly recap (nutrx Pro, docs/pro/design/5-weekly-recap): a forest hero with the week's full days, goals met
/// and summary, fact cards (steadiest, slipped, the day you tend to miss, streak) and the last eight weeks to switch
/// between. Before the first full week: "Your first recap arrives Sunday".
struct WeeklyRecapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = RecapViewModel()

    private var streaksEnabled: Bool { allPreferences.first?.streaksEnabled != false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap + 2) {
                if let recap = viewModel.selected {
                    hero(recap)
                    factCards(recap)
                    if viewModel.weeks.count > 1 { earlierWeeks }
                } else if let running = viewModel.runningWeek {
                    firstWeekHero(running)
                    explainer
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .background(Theme.surfaceGround)
        .navigationTitle("Weekly recap")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let recap = viewModel.selected {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText(recap)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear { viewModel.refresh(context: modelContext, streaksEnabled: streaksEnabled) }
        .task(id: viewModel.selected?.weekStart) {
            if let recap = viewModel.selected { await viewModel.loadSummary(for: recap) }
        }
    }

    // MARK: - Hero

    private func hero(_ recap: WeeklyRecap) -> some View {
        let text = RecapText(recap)
        return heroCard(
            ring: SegmentedDayRing(met: recap.fullDays, total: 7, caption: text.ringLabel),
            ringSummary: "\(recap.fullDays) of 7 full days",
            eyebrow: text.range,
            title: text.headline,
            body: viewModel.summary(for: recap)
        )
    }

    private func firstWeekHero(_ running: WeeklyRecap) -> some View {
        heroCard(
            ring: SegmentedDayRing(met: running.daysLoggedSoFar, total: 7,
                                   caption: running.daysLoggedSoFar == 1 ? "day logged" : "days logged", showsTotal: false),
            ringSummary: running.daysLoggedSoFar == 1 ? "1 day logged" : "\(running.daysLoggedSoFar) days logged",
            eyebrow: "This week",
            title: RecapText.firstTitle,
            body: RecapText.firstBody(daysLogged: running.daysLoggedSoFar)
        )
    }

    private func heroCard(ring: SegmentedDayRing, ringSummary: String, eyebrow: String, title: String,
                          body: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                // At accessibility sizes the ring gives its room to the words (docs/pro/design/5-weekly-recap AX).
                if !dynamicTypeSize.isAccessibilitySize {
                    ring.frame(width: 88, height: 88)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Theme.onForestSecondary)
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.onForestPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // The ring's number, in words where the ring is left out.
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(ringSummary)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.onForestSecondary)
                    }
                }
            }
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.onForestPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: body)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.forest, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fact cards

    private func factCards(_ recap: WeeklyRecap) -> some View {
        let cards = RecapText(recap).cards
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: Theme.Spacing.cardGap), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.cardGap) {
            ForEach(cards, id: \.label) { card in
                factCard(card)
            }
        }
    }

    private func factCard(_ card: RecapText.Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                if !dynamicTypeSize.isAccessibilitySize { cardIcon(card) }
                Text(card.value)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Text(card.detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cardIcon(_ card: RecapText.Card) -> some View {
        switch card.kind {
        case .steadiest, .slipped:
            if let id = card.nutrientID, let nutrient = viewModel.nutrientsByID[id] {
                NutrientIconTile(nutrient: nutrient, size: 32)
            }
        case .weekday:
            NutrientIconTile(tint: .indigo, symbolName: "calendar", size: 32)
        case .streak:
            NutrientIconTile(tint: .coral, symbolName: "flame", size: 32)
        }
    }

    // MARK: - Earlier weeks

    private var earlierWeeks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Earlier weeks")
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
            // Spread across the card when the weeks fit; scrolled to the newest when they don't.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    ForEach(viewModel.weeks, id: \.weekStart) { week in
                        weekButton(week).frame(maxWidth: .infinity)
                    }
                }
                .padding(8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.weeks, id: \.weekStart) { week in
                            weekButton(week)
                        }
                    }
                    .padding(8)
                }
                .defaultScrollAnchor(.trailing)
            }
            .cardStyle()
        }
    }

    private func weekButton(_ week: WeeklyRecap) -> some View {
        let isSelected = week.weekStart == viewModel.selected?.weekStart
        let fraction = week.goalsCounted > 0 ? Double(week.goalsMet) / Double(week.goalsCounted) : 0
        return Button {
            viewModel.selectedWeek = week.weekStart
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Theme.surfaceChip, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Theme.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 30, height: 30)
                Text(week.weekStart, format: .dateTime.day())
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // a fixed 40pt column
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceChip)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week of \(week.weekStart.formatted(.dateTime.day().month(.wide)))")
        .accessibilityValue("\(week.goalsMet) of \(week.goalsCounted) goals met")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - First week

    private var explainer: some View {
        Text(RecapText.explainer(device: UIDevice.current.model))
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private func shareText(_ recap: WeeklyRecap) -> String {
        let text = RecapText(recap)
        return "My week in nutrx, \(text.range): \(text.headline). \(viewModel.summary(for: recap))"
    }
}

#Preview {
    NavigationStack {
        WeeklyRecapView()
    }
    .modelContainer(previewContainer)
}
