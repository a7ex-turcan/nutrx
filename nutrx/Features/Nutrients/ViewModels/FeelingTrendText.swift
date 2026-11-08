import Foundation

/// The words of "With how you feel" in a nutrient's analytics (nutrx Pro, #133, docs/pro/HOW-YOU-FEEL.md §3), as
/// `HealthText` is for Apple Health: day counts, "on average", never a cause or advice. Pure.
struct FeelingTrendText {
    let nutrientName: String
    let unit: String
    let goal: AnalyticsGoal
    var locale: Locale = .current

    static let title = "With how you feel"
    static let period = "Last 28 days"

    static func footer(device: String) -> String {
        "Patterns in your own answers, not causes. Worked out on this \(device)."
    }

    /// How you feel is off and has no answers.
    static let turnOn = "See how your answers to How you feel line up with this nutrient. Turn it on in Settings → "
        + "How you feel."

    static func teaser(device: String) -> String {
        "See how your answers to How you feel line up with this nutrient, worked out on this \(device)."
    }

    static let notEnoughData = "Patterns appear after about two weeks of answering How you feel on days you log."

    /// "Sleep last night: 9 of 14 days".
    static func progress(question: String, pairedDays: Int) -> String {
        "\(question): \(pairedDays) of \(FeelingTrends.minimumPairedDays) days"
    }

    var noPattern: String {
        "No clear difference yet between days you \(conditionVerb) and other days."
    }

    // MARK: - Findings

    /// "On days you reach your Magnesium goal, you rated your Energy 3.9 on average, vs 3.2 on other days."
    /// "After days Caffeine passes 300 mg, you had a headache on 5 of 9 days, vs 2 of 15 other days."
    func sentence(_ finding: FeelingTrends.Finding) -> String {
        let after = finding.question.aboutNightBefore
        let condition = "\(after ? "After" : "On") days \(conditionClause(finding))"
        let others = after ? "after other days" : "on other days"
        switch finding.question.kind {
        case .scale:
            return "\(condition), you rated your \(name(finding.question)) \(score(finding.first.average)) on average, "
                + "vs \(score(finding.second.average)) \(others)."
        case .yesNo:
            return "\(condition), \(yesPhrase(finding.question)) on \(finding.first.yesDays) of \(finding.first.days) "
                + "days, vs \(finding.second.yesDays) of \(finding.second.days) other days."
        }
    }

    /// The two bars' labels: "Goal met" / "Other days", "Over 300 mg" / "Other days".
    func labels(_ finding: FeelingTrends.Finding) -> (String, String) {
        if let threshold = finding.threshold { return ("Over \(amountText(threshold))", "Other days") }
        return ("Goal met", "Other days")
    }

    /// The bars' values: "3.9", or "5 of 9".
    func value(_ group: FeelingTrends.Finding.Group, of finding: FeelingTrends.Finding) -> String {
        finding.question.kind == .scale ? score(group.average) : "\(group.yesDays) of \(group.days)"
    }

    /// "Based on 9 days over 300 mg and 19 days under."
    func basis(_ finding: FeelingTrends.Finding) -> String {
        let (a, b) = (finding.first.days, finding.second.days)
        if let threshold = finding.threshold {
            return "Based on \(days(a)) over \(amountText(threshold)) and \(days(b)) under."
        }
        return "Based on \(days(a)) with the goal met and \(days(b)) without."
    }

    // MARK: - Parts

    /// "you reach your Magnesium goal", "Caffeine passes 300 mg".
    private func conditionClause(_ finding: FeelingTrends.Finding) -> String {
        if let threshold = finding.threshold { return "\(nutrientName) passes \(amountText(threshold))" }
        return "you reach your \(nutrientName) goal"
    }

    /// For "No clear difference yet between days you …": "reach your Magnesium goal", "come near your Caffeine limit".
    private var conditionVerb: String {
        goal.goalType == .maximum ? "come near your \(nutrientName) limit" : "reach your \(nutrientName) goal"
    }

    /// Sleep reads "Sleep", not "Sleep last night", in a sentence.
    private func name(_ question: FeelingTrends.Question) -> String {
        question.preset == .sleep ? "Sleep" : question.title
    }

    private func yesPhrase(_ question: FeelingTrends.Question) -> String {
        switch question.preset {
        case .headache: "you had a headache"
        case .aches: "you had aches or pains"
        default: "you answered yes to \(question.title)"
        }
    }

    /// One decimal: "3.9".
    func score(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    func amountText(_ amount: Double) -> String {
        let digits = amount >= 10 ? 0 : 1
        return "\(amount.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))) \(unit)"
    }

    private func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }
}
