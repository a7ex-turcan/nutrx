import Foundation

/// Today's goals at a glance: how many are met, and the day-score card headline (DESIGN.md §4.3).
struct DayScore: Equatable {
    let met: Int
    let total: Int

    init(met: Int, total: Int) {
        self.total = max(total, 0)
        self.met = min(max(met, 0), self.total)
    }

    init(progresses: [GoalProgress]) {
        self.init(met: progresses.filter(\.countsAsMet).count, total: progresses.count)
    }

    var remaining: Int { total - met }

    /// "Let's get started" → "Halfway there — 3 to go" (only when 40–60% met) / "2 to go" → "All done for today".
    var title: String {
        if met == 0 { return "Let's get started" }
        if met == total { return "All done for today" }
        let share = Double(met) / Double(total)
        return (0.4...0.6).contains(share) ? "Halfway there — \(remaining) to go" : "\(remaining) to go"
    }
}
