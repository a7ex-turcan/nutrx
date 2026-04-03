import SwiftUI

struct NutrientProgressBar: View {
    let current: Double
    let target: Double
    var goalType: GoalType = .minimum
    var upperBound: Double? = nil

    // For max/range, the limit maps to 85% of bar width so overflow is visible
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
            guard target > 0 else { return .blue }
            if current > target {
                // Past target: yellow, then gradually toward red at 2x
                let overFraction = min((current - target) / target, 1.0)
                return Self.blend(from: .systemYellow, to: .systemRed, fraction: overFraction)
            } else if current == target {
                return .green
            }
            let fraction = current / target
            return Self.blend(from: .systemBlue, to: .systemGreen, fraction: fraction)

        case .maximum:
            guard target > 0 else { return .orange }
            if current > target {
                return Color(.systemRed)
            }
            let fraction = current / target
            return Self.blend(from: .systemOrange, to: .systemRed, fraction: fraction)

        case .range:
            guard let upper = upperBound, upper > 0 else { return .blue }
            if current > upper {
                let overFraction = min((current - upper) / upper, 1.0)
                return Self.blend(from: .systemYellow, to: .systemRed, fraction: overFraction)
            } else if current >= target {
                return .green
            } else {
                guard target > 0 else { return .blue }
                let fraction = min(current / target, 1.0)
                return Self.blend(from: .systemBlue, to: .systemGreen, fraction: fraction)
            }
        }
    }

    // MARK: - Color interpolation

    private static func blend(from: UIColor, to: UIColor, fraction: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(min(max(fraction, 0), 1))
        return Color(
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f)
        )
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
        NutrientProgressBar(current: 1500, target: 2000)
        NutrientProgressBar(current: 2000, target: 2000)

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
