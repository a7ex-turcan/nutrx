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

    /// Analytics cards use a roomier inset than list cards (design source: 18pt).
    @State private var showHealthIntro = false
    private let cardPadding: CGFloat = 18

    var body: some View {
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
                                         nutrientName: nutrient.name, unit: nutrient.unit)
                    }
                    .padding(cardPadding)
                    .cardStyle()
                }

                SupplyCard(nutrient: nutrient)

                if let pattern = viewModel.weekdayPattern {
                    WeekdayHeatmap(pattern: pattern, tint: nutrient.tint)
                        .padding(cardPadding)
                        .cardStyle()
                }

                HealthTrendsCard(nutrient: nutrient, state: viewModel.healthState,
                                 isConnected: viewModel.isHealthConnected) { showHealthIntro = true }

                remindersRow
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.sectionTop)
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
