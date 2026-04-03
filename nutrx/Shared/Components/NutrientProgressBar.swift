import SwiftUI

struct NutrientProgressBar: View {
    let current: Double
    let target: Double
    var goalType: GoalType = .minimum
    var upperBound: Double? = nil

    // For range, upperBound maps to 85% of bar width so overflow is visible
    private static let rangeScale: Double = 0.85

    private var progress: Double {
        switch goalType {
        case .minimum:
            guard target > 0 else { return 0 }
            return current / target
        case .maximum:
            guard target > 0 else { return 0 }
            return (current / target) * Self.rangeScale
        case .range:
            guard let upper = upperBound, upper > 0 else { return 0 }
            return (current / upper) * Self.rangeScale
        }
    }

    private var barColor: Color {
        switch goalType {
        case .minimum:
            if current > target {
                return .orange
            } else if current >= target {
                return .green
            } else {
                return .blue
            }
        case .maximum:
            if current > target {
                return Color(.systemRed).opacity(0.85)
            } else if current > 0 {
                return .orange
            } else {
                return .orange.opacity(0.3)
            }
        case .range:
            guard let upper = upperBound else { return .blue }
            if current > upper {
                return .orange
            } else if current >= target {
                return .green
            } else {
                return .blue
            }
        }
    }

    // Range zone positions (as fractions of full bar)
    private var rangeZone: (start: Double, end: Double)? {
        guard goalType == .range, let upper = upperBound, upper > 0 else { return nil }
        return (start: (target / upper) * Self.rangeScale, end: Self.rangeScale)
    }

    // Tick mark positions (as fractions of full bar)
    private var tickPositions: [Double] {
        switch goalType {
        case .minimum:
            return []
        case .maximum:
            return [Self.rangeScale]
        case .range:
            guard let upper = upperBound, upper > 0 else { return [] }
            return [(target / upper) * Self.rangeScale, Self.rangeScale]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))

                // Range zone background band
                if let zone = rangeZone {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: geo.size.width * (zone.end - zone.start))
                        .offset(x: geo.size.width * zone.start)
                }

                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(barColor)
                    .frame(width: min(geo.size.width, geo.size.width * progress))

                // Tick marks
                ForEach(tickPositions, id: \.self) { pos in
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: 1.5, height: geo.size.height)
                        .offset(x: geo.size.width * min(pos, 1.0) - 0.75)
                }
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Minimum").font(.caption).foregroundStyle(.secondary)
        NutrientProgressBar(current: 500, target: 2000)
        NutrientProgressBar(current: 2000, target: 2000)
        NutrientProgressBar(current: 2500, target: 2000)

        Text("Maximum").font(.caption).foregroundStyle(.secondary)
        NutrientProgressBar(current: 0, target: 200, goalType: .maximum)
        NutrientProgressBar(current: 100, target: 200, goalType: .maximum)
        NutrientProgressBar(current: 250, target: 200, goalType: .maximum)

        Text("Range").font(.caption).foregroundStyle(.secondary)
        NutrientProgressBar(current: 0.5, target: 1.0, goalType: .range, upperBound: 2.0)
        NutrientProgressBar(current: 1.5, target: 1.0, goalType: .range, upperBound: 2.0)
        NutrientProgressBar(current: 2.5, target: 1.0, goalType: .range, upperBound: 2.0)
    }
    .padding()
}
