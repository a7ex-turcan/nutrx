import SwiftUI

struct NutrientProgressBar: View {
    let current: Double
    let target: Double

    private var progress: Double {
        guard target > 0 else { return 0 }
        return current / target
    }

    private var isComplete: Bool {
        progress >= 1.0
    }

    private var isExceeded: Bool {
        progress > 1.0
    }

    private var barColor: Color {
        if isExceeded {
            return .orange
        } else if isComplete {
            return .green
        } else {
            return .blue
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))

                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(barColor)
                    .frame(width: min(geo.size.width, geo.size.width * progress))
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        NutrientProgressBar(current: 500, target: 2000)
        NutrientProgressBar(current: 1500, target: 2000)
        NutrientProgressBar(current: 2000, target: 2000)
        NutrientProgressBar(current: 2500, target: 2000)
    }
    .padding()
}
