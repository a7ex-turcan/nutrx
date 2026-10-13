import Foundation

/// Today's goals at a glance: how many are met, and the day-score card headline (DESIGN.md §4.3).
struct DayScore: Equatable {
    let met: Int
    let total: Int
    /// Goals past an "at most" limit or a range's upper bound: not met, but logging more won't help.
    let overLimit: Int

    init(met: Int, total: Int, overLimit: Int = 0) {
        self.total = max(total, 0)
        self.met = min(max(met, 0), self.total)
        self.overLimit = min(max(overLimit, 0), self.total - self.met)
    }

    init(progresses: [GoalProgress]) {
        self.init(met: progresses.filter(\.countsAsMet).count, total: progresses.count,
                  overLimit: progresses.filter { $0.status == .overLimit }.count)
    }

    /// Goals not met, including any over a limit.
    var remaining: Int { total - met }

    /// Goals that still need more: "3 to go" never counts one that's over its limit.
    var toGo: Int { remaining - overLimit }

    /// "Let's get started" → "Halfway there — 3 to go" (only when 40–60% met) / "2 to go" → "All done for today".
    /// With nothing left to log toward but a goal over its limit: "1 over limit" (the widgets say the same).
    /// The count and its words are joined with non-breaking spaces so a wrap never leaves the number on its own.
    var title: String {
        if toGo == 0, overLimit > 0 { return "\(overLimit)\u{00A0}over\u{00A0}limit" }
        if met == 0 { return "Let's get started" }
        if met == total { return "All done for today" }
        let share = Double(met) / Double(total)
        let toGoText = "\(toGo)\u{00A0}to\u{00A0}go"
        return (0.4...0.6).contains(share) ? "Halfway there — \(toGoText)" : toGoText
    }
}
