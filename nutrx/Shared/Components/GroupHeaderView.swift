import SwiftUI

struct GroupHeaderView: View {
    let name: String
    let isCollapsed: Bool
    let intakes: [(current: Double, target: Double)]
    let onToggle: () -> Void

    private var aggregateColor: Color {
        guard !intakes.isEmpty else { return .blue }
        let anyExceeded = intakes.contains { $0.target > 0 && $0.current > $0.target }
        let allComplete = intakes.allSatisfy { $0.target > 0 && $0.current >= $0.target }

        if anyExceeded { return .orange }
        if allComplete { return .green }
        return .blue
    }

    private var aggregateProgress: Double {
        let totalTarget = intakes.reduce(0.0) { $0 + $1.target }
        guard totalTarget > 0 else { return 0 }
        let totalCurrent = intakes.reduce(0.0) { $0 + $1.current }
        return totalCurrent / totalTarget
    }

    private var completedCount: Int {
        intakes.filter { $0.target > 0 && $0.current >= $0.target }.count
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: isCollapsed ? 8 : 0) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !intakes.isEmpty {
                        Text("\(completedCount)/\(intakes.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(completedCount == intakes.count ? .green : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }

                if isCollapsed {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(aggregateColor)
                                .frame(width: min(geo.size.width, geo.size.width * aggregateProgress))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
