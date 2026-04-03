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
                        goalType: nutrient.goalType,
                        upperBound: nutrient.upperBound,
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
                        period: vm.selectedPeriod,
                        goalType: nutrient.goalType,
                        upperBound: nutrient.upperBound
                    )

                    DayOfWeekCard(
                        dayOfWeekAverages: vm.dayOfWeekAverages,
                        dailyTarget: nutrient.dailyTarget,
                        unit: nutrient.unit,
                        goalType: nutrient.goalType,
                        upperBound: nutrient.upperBound
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
