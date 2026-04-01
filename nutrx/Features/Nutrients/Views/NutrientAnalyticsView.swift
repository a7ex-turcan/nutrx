import SwiftUI
import SwiftData

struct NutrientAnalyticsView: View {
    let nutrient: Nutrient
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NutrientAnalyticsViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let vm = viewModel {
                    DailyIntakeChartCard(
                        dailyTotals: vm.dailyTotals,
                        dailyTarget: nutrient.dailyTarget,
                        unit: nutrient.unit,
                        selectedPeriod: Binding(
                            get: { vm.selectedPeriod },
                            set: {
                                vm.selectedPeriod = $0
                                vm.refresh()
                            }
                        )
                    )

                    PeriodStatsCard(
                        hitRate: vm.hitRate,
                        average: vm.periodAverage,
                        dailyTarget: nutrient.dailyTarget,
                        unit: nutrient.unit,
                        period: vm.selectedPeriod
                    )

                    DayOfWeekCard(
                        dayOfWeekAverages: vm.dayOfWeekAverages,
                        dailyTarget: nutrient.dailyTarget,
                        unit: nutrient.unit
                    )
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(nutrient.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = NutrientAnalyticsViewModel(
                    nutrient: nutrient,
                    modelContext: modelContext
                )
            }
        }
    }
}
