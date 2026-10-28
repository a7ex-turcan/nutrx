import SwiftData
import SwiftUI

/// Which recap the Recaps screen shows (#136, docs/pro/RECAPS.md §5).
enum RecapTab: String, CaseIterable, Identifiable {
    case week
    case month

    var id: Self { self }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        }
    }
}

/// The recaps (nutrx Pro; docs/pro/design/5-weekly-recap, months since #136): a Week / Month switch, then a forest
/// hero with the period's full days, goals met and summary, fact cards, and the earlier weeks or months to switch
/// between. The month adds a small calendar of its full days. Before there's anything to sum up: when the first
/// recap arrives.
struct RecapsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]
    @State private var viewModel = RecapViewModel()
    @State private var tab: RecapTab
    /// Apple Health insights (#102): one line at the end while they're gathering, or a pointer once one is ready.
    @State private var healthStatus: HealthInsights.Status?

    init(tab: RecapTab = .week) {
        _tab = State(initialValue: tab)
    }

    private var streaksEnabled: Bool { allPreferences.first?.streaksEnabled != false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.cardGap + 2) {
                Picker("Recap", selection: $tab) {
                    ForEach(RecapTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                switch tab {
                case .week: weekContent
                case .month: monthContent
                }
                if let status = healthStatus, let line = HealthText.recapLine(status) {
                    healthLine(line)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .readableColumn()
        .background(Theme.surfaceGround)
        .navigationTitle("Recaps")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let share = shareText {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: share) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear { viewModel.refresh(context: modelContext, streaksEnabled: streaksEnabled) }
        // The recap is Pro already; the line needs Health connected (`load` is nil otherwise).
        .task { healthStatus = await HealthInsights.load(context: modelContext) }
        .task(id: viewModel.selected?.weekStart) {
            if let recap = viewModel.selected { await viewModel.loadSummary(for: recap) }
        }
        .task(id: viewModel.selectedMonthRecap?.monthStart) {
            if let recap = viewModel.selectedMonthRecap { await viewModel.loadSummary(for: recap) }
        }
    }

    // MARK: - Week

    @ViewBuilder
    private var weekContent: some View {
        if let recap = viewModel.selected {
            let text = RecapText(recap)
            RecapHeroCard(
                ring: SegmentedDayRing(met: recap.fullDays, total: recap.dayCount, caption: text.ringLabel),
                ringSummary: "\(recap.fullDays) of \(recap.dayCount) full days",
                eyebrow: text.range, title: text.headline, summary: viewModel.summary(for: recap))
            RecapFactGrid(cards: text.cards, nutrientsByID: viewModel.nutrientsByID)
            if viewModel.weeks.count > 1 {
                EarlierPicker(title: "Earlier weeks", items: viewModel.weeks.map { week in
                    EarlierPicker.Item(id: week.weekStart, label: week.weekStart.formatted(.dateTime.day()),
                                       accessibilityLabel: "Week of \(week.weekStart.formatted(.dateTime.day().month(.wide)))",
                                       goalsMet: week.goalsMet, goalsCounted: week.goalsCounted)
                }, selected: recap.weekStart) { viewModel.selectedWeek = $0 }
            }
        } else if let running = viewModel.runningWeek {
            RecapHeroCard(
                ring: SegmentedDayRing(met: running.daysLoggedSoFar, total: 7,
                                       caption: running.daysLoggedSoFar == 1 ? "day logged" : "days logged",
                                       showsTotal: false),
                ringSummary: running.daysLoggedSoFar == 1 ? "1 day logged" : "\(running.daysLoggedSoFar) days logged",
                eyebrow: "This week", title: RecapText.firstTitle,
                summary: RecapText.firstBody(daysLogged: running.daysLoggedSoFar))
            explainer
        }
    }

    // MARK: - Month

    @ViewBuilder
    private var monthContent: some View {
        if let recap = viewModel.selectedMonthRecap {
            let text = MonthlyRecapText(recap)
            RecapHeroCard(
                ring: SegmentedDayRing(met: recap.fullDays, total: recap.dayCount, caption: text.ringLabel),
                ringSummary: "\(recap.fullDays) of \(recap.dayCount) full days",
                eyebrow: text.range, title: text.headline, summary: viewModel.summary(for: recap))
            RecapFactGrid(cards: text.cards, nutrientsByID: viewModel.nutrientsByID)
            RecapMonthGrid(recap: recap)
            if viewModel.monthChoices.count > 1 {
                EarlierPicker(title: "Earlier months", items: viewModel.monthChoices.map { month in
                    let name = MonthlyRecapText(month).monthName
                    return EarlierPicker.Item(id: month.monthStart, label: String(name.prefix(3)),
                                              accessibilityLabel: month.isMonthOver ? name : "\(name) so far",
                                              goalsMet: month.goalsMet, goalsCounted: month.goalsCounted)
                }, selected: recap.monthStart) { viewModel.selectedMonth = $0 }
            }
        } else {
            let calendar = Calendar.current
            let next = calendar.date(byAdding: .month, value: 1,
                                     to: MonthlyRecap.monthStart(containing: .now, calendar: calendar))!
            let logged = viewModel.monthDaysLoggedSoFar
            RecapHeroCard(
                ring: SegmentedDayRing(met: logged, total: viewModel.monthLength,
                                       caption: logged == 1 ? "day logged" : "days logged", showsTotal: false),
                ringSummary: logged == 1 ? "1 day logged" : "\(logged) days logged",
                eyebrow: "This month", title: MonthlyRecapText.firstTitle(nextMonthStart: next),
                summary: MonthlyRecapText.firstBody(daysLogged: logged))
        }
    }

    // MARK: - Pieces

    private var explainer: some View {
        Text(RecapText.explainer(device: UIDevice.current.model))
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private func healthLine(_ line: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(NutrientTint.coral.tileGlyph)
                .accessibilityHidden(true)
            Text(line)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    /// The shown recap's range, headline and summary, for the share sheet.
    private var shareText: String? {
        switch tab {
        case .week:
            guard let recap = viewModel.selected else { return nil }
            let text = RecapText(recap)
            return "My week in nutrx, \(text.range): \(text.headline). \(viewModel.summary(for: recap))"
        case .month:
            guard let recap = viewModel.selectedMonthRecap else { return nil }
            let text = MonthlyRecapText(recap)
            return "My \(text.range) in nutrx: \(text.headline). \(viewModel.summary(for: recap))"
        }
    }
}

/// "Earlier weeks" / "Earlier months": a row of small goals-met rings to switch between, spread across the card
/// when they fit and scrolled to the newest when they don't.
private struct EarlierPicker: View {
    struct Item: Identifiable {
        let id: Date
        let label: String
        let accessibilityLabel: String
        let goalsMet: Int
        let goalsCounted: Int
    }

    let title: String
    let items: [Item]
    let selected: Date
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    ForEach(items) { item in button(item).frame(maxWidth: .infinity) }
                }
                .padding(8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(items) { item in button(item) }
                    }
                    .padding(8)
                }
                .defaultScrollAnchor(.trailing)
            }
            .cardStyle()
        }
    }

    private func button(_ item: Item) -> some View {
        let isSelected = item.id == selected
        let fraction = item.goalsCounted > 0 ? Double(item.goalsMet) / Double(item.goalsCounted) : 0
        return Button {
            onSelect(item.id)
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
                Text(item.label)
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
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue("\(item.goalsMet) of \(item.goalsCounted) \(GoalProgress.goals(item.goalsCounted)) met")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        RecapsView()
    }
    .modelContainer(previewContainer)
}
