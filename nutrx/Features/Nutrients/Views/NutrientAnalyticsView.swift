import SwiftUI
import SwiftData

/// Per-nutrient analytics (DESIGN.md §5.3), pushed from My Nutrients: header, period picker, stats + chart card,
/// weekday heatmap, and a Reminders row. "Edit" opens the nutrient form.
struct NutrientAnalyticsView: View {
    let nutrient: Nutrient
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NutrientAnalyticsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NutrientAnalyticsContent(nutrient: nutrient, viewModel: viewModel)
            } else {
                Theme.surfaceGround.ignoresSafeArea()
            }
        }
        .onAppear {
            if let viewModel {
                // Back from another tab (e.g. logged on Today) — pick up new intake.
                viewModel.refresh()
            } else {
                viewModel = NutrientAnalyticsViewModel(nutrient: nutrient, modelContext: modelContext)
            }
        }
    }
}

private struct NutrientAnalyticsContent: View {
    let nutrient: Nutrient
    @Bindable var viewModel: NutrientAnalyticsViewModel

    @State private var editDraft = NutrientDraft()
    @State private var showEdit = false
    @State private var showReminders = false
    @State private var headerScrolledAway = false

    @State private var showHealthIntro = false
    @Environment(ProAccess.self) private var proAccess: ProAccess?
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(\.widthClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The content column's width, which decides whether the heatmap and Supply sit side by side.
    @State private var contentWidth: CGFloat = 0

    private static let healthCardID = "health-trends"

    /// On large screens (docs/design/large-screens/LAYOUT.md, #153): 24 pt padding (40 on wide), the content capped
    /// at 760 pt and centred, a taller chart on wide, and the heatmap and Supply side by side from 656 pt.
    private var isLarge: Bool { widthClass != .compact }
    private static let maxContentWidth: CGFloat = 760
    private static let sideBySideMinimum: CGFloat = 656

    /// Analytics cards use a roomier inset than list cards (design source: 18pt).
    private let cardPadding: CGFloat = 18

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.cardGap + 2) {
                    header
                        .padding(.bottom, 6)

                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(AnalyticsPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if let summary = viewModel.summary {
                        VStack(alignment: .leading, spacing: 22) {
                            StatTriplet(stats: viewModel.stats)
                            DailyIntakeChart(days: summary.days, goal: viewModel.goal, tint: nutrient.tint,
                                             nutrientName: nutrient.name, unit: nutrient.unit,
                                             height: widthClass == .wide ? 240 : 170)
                        }
                        .padding(cardPadding)
                        .cardStyle()
                    }

                    // One column at the largest text sizes, whatever the width (#155). Side by side, both are as
                    // tall as the taller (#215); a one-row Supply card (the free teaser, Set up) goes full width
                    // above the heatmap instead, as on iPhone, rather than leave a half-width card with a gap under it.
                    // A weekly schedule has no weekday pattern, so then Supply goes full width too.
                    if contentWidth >= Self.sideBySideMinimum, !dynamicTypeSize.isAccessibilitySize,
                       viewModel.weekdayPattern != nil,
                       SupplyCard.showsStatus(for: nutrient, isPro: proAccess?.isPro == true) {
                        HStack(alignment: .top, spacing: Theme.Spacing.cardGap + 2) {
                            heatmapCard
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            SupplyCard(nutrient: nutrient)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        SupplyCard(nutrient: nutrient)
                        heatmapCard
                    }

                    HealthTrendsCard(nutrient: nutrient, state: viewModel.healthState,
                                     isConnected: viewModel.isHealthConnected) { showHealthIntro = true }
                        .id(Self.healthCardID)

                    remindersRow
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
                .frame(maxWidth: isLarge ? (dynamicTypeSize.isAccessibilitySize ? ReadableColumn.maxWidth
                                                                                 : Self.maxContentWidth) : nil)
                .padding(.horizontal, isLarge ? widthClass.minimumMargin : Theme.Spacing.screenMargin)
                .padding(.bottom, Theme.Spacing.sectionTop)
                .frame(maxWidth: .infinity)
            }
            // Opened from Today's Apple Health card (#102): scroll to where the insights are.
            .task(id: router?.healthNutrientID) {
                guard router?.healthNutrientID == nutrient.id else { return }
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation { proxy.scrollTo(Self.healthCardID, anchor: .center) }
                router?.healthNutrientID = nil
            }
        }
        .sheet(isPresented: $showHealthIntro) {
            HealthIntroView { Task { await viewModel.refreshHealth() } }
        }
        .task { await viewModel.refreshHealth() }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 56
        } action: { _, scrolledAway in
            headerScrolledAway = scrolledAway
        }
        .background(Theme.surfaceGround)
        // The header carries the name; the bar only shows it once the header has scrolled away.
        .navigationTitle(headerScrolledAway ? nutrient.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editDraft.populate(from: nutrient)
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NutrientFormView(draft: editDraft, title: "Edit Nutrient", buttonLabel: "Save", nutrient: nutrient) {
                editDraft.apply(to: nutrient)
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showReminders) {
            NutrientRemindersSheet(nutrient: nutrient)
        }
    }

    @ViewBuilder
    private var heatmapCard: some View {
        if let pattern = viewModel.weekdayPattern {
            WeekdayHeatmap(pattern: pattern, tint: nutrient.tint)
                .padding(cardPadding)
                // As tall as the Supply card beside it on large widths (#215).
                .frame(maxHeight: .infinity, alignment: .top)
                .cardStyle()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            NutrientIconTile(nutrient: nutrient, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.name)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(NutrientSummaryText.goalLine(for: nutrient))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var remindersRow: some View {
        Button {
            showReminders = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bell")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("Reminders")
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                Text(NutrientSummaryText.reminderSummary(for: nutrient))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, cardPadding)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardStyle()
    }
}

private struct NutrientAnalyticsPreview: View {
    @Query(sort: \Nutrient.sortOrder) private var nutrients: [Nutrient]

    var body: some View {
        NavigationStack {
            if let nutrient = nutrients.first {
                NutrientAnalyticsView(nutrient: nutrient)
            }
        }
    }
}

#Preview("Light") {
    NutrientAnalyticsPreview()
        .modelContainer(previewContainer)
}

#Preview("Dark") {
    NutrientAnalyticsPreview()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
