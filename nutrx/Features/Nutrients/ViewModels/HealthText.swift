import Foundation

/// The "With Apple Health" card's words (docs/pro/design/6-health-trends). Careful by design: "seems to", "on
/// average", the number of days behind each finding, and never a cause or advice.
struct HealthText {
    let nutrientName: String
    let unit: String
    let goal: AnalyticsGoal
    var locale: Locale = .current

    static let title = "With Apple Health"
    static let period = "Last 28 days"
    static func footer(device: String) -> String {
        "Patterns in your own data, not causes. Worked out on this \(device)."
    }
    static let notEnoughData = "Trends appear after about two weeks of logging with Apple Health connected."
    static let noHealthData = "Apple Health has no sleep, workouts or active energy for the last four weeks."

    static func teaser(device: String) -> String {
        "See how this nutrient lines up with your sleep and workouts. Private — read on your \(device) only."
    }

    /// "9 of 14 days".
    static func progress(pairedDays: Int) -> String {
        "\(min(pairedDays, HealthTrends.minimumPairedDays)) of \(HealthTrends.minimumPairedDays) days"
    }

    var noPattern: String {
        "No clear pattern yet. Your \(nutrientName) looks about the same whatever your sleep and workouts."
    }

    static func checked(days: Int) -> String { "Checked \(days) days · updates daily" }

    // MARK: - Where insights appear (#102)

    static let connectedTitle = "Apple Health is connected"
    static let connectedBody = "Keep logging as usual. In about two weeks, each nutrient's analytics will show how it lines up with your sleep and workouts."
    static let whereLine = "You'll find them in My Nutrients › a nutrient › With Apple Health."

    /// Today's card title, or nil when the status doesn't call for the card.
    static func todayTitle(_ status: HealthInsights.Status) -> String? {
        switch status {
        case .gathering: "Insights from Apple Health are on the way"
        case .ready: "Your first Apple Health insight is ready"
        case .noHealthData, .noPattern: nil
        }
    }

    /// "Keep logging: Vitamin D has 9 of 14 days with your logs and Health data." / "See how Vitamin D lines up with
    /// your sleep and workouts."
    static func todayBody(_ status: HealthInsights.Status) -> String? {
        switch status {
        case .gathering(_, let name, let days):
            "Keep logging: \(name) has \(progress(pairedDays: days)) with your logs and Health data."
        case .ready(_, let name):
            "See how \(name) lines up with your sleep and workouts."
        case .noHealthData, .noPattern: nil
        }
    }

    /// Settings → Apple Health, under "Where you'll see it".
    static func settingsStatus(_ status: HealthInsights.Status) -> String {
        switch status {
        case .gathering(_, let name, let days):
            "So far: \(progress(pairedDays: days)) for \(name). Insights start at \(HealthTrends.minimumPairedDays)."
        case .ready(_, let name): "Ready: see \(name)'s analytics."
        case .noPattern: "Checked: no clear pattern yet. It updates daily."
        case .noHealthData: noHealthData
        }
    }

    /// One line at the end of the weekly recap, or nil.
    static func recapLine(_ status: HealthInsights.Status) -> String? {
        switch status {
        case .gathering: "Apple Health insights start after about two weeks of logging."
        case .ready(_, let name): "See how \(name) lines up with your sleep and workouts in its analytics."
        case .noHealthData, .noPattern: nil
        }
    }

    // MARK: - Findings

    /// "On days caffeine passes 300 mg, you seem to sleep about 40 minutes less on average."
    func sentence(_ finding: HealthTrends.Finding) -> String {
        switch finding.kind {
        case .sleep:
            let minutes = Self.roundedMinutes(abs(finding.difference))
            let direction = finding.difference < 0 ? "less" : "more"
            return "\(sleepCondition(finding)), you seem to sleep about \(minutes) minutes \(direction) on average."
        case .workouts, .activeEnergy:
            let amount = amountText(abs(finding.difference))
            let direction = finding.difference < 0 ? "less" : "more"
            let when = finding.kind == .workouts ? "On days you work out" : "On your more active days"
            return "\(when), you log about \(amount) \(direction) \(nutrientName) on average."
        }
    }

    private func sleepCondition(_ finding: HealthTrends.Finding) -> String {
        if goal.goalType == .maximum, let threshold = finding.threshold {
            return "On days \(nutrientName) passes \(amountText(threshold))"
        }
        return "On days you reach your \(nutrientName) goal"
    }

    /// The two bars' labels: "Over 300 mg" / "Other days", "Workout days" / "Rest days".
    func labels(_ finding: HealthTrends.Finding) -> (String, String) {
        switch finding.kind {
        case .sleep:
            if goal.goalType == .maximum, let threshold = finding.threshold { return ("Over \(amountText(threshold))", "Other days") }
            return ("Goal met", "Other days")
        case .workouts: return ("Workout days", "Rest days")
        case .activeEnergy: return ("More active", "Less active")
        }
    }

    /// The bars' values: "6 h 35" for sleep, "290 mg" for intake.
    func value(_ group: HealthTrends.Finding.Group, of finding: HealthTrends.Finding) -> String {
        finding.kind == .sleep ? Self.sleepText(group.average) : amountText(group.average)
    }

    /// "Based on 9 days over 300 mg and 19 days under."
    func basis(_ finding: HealthTrends.Finding) -> String {
        let (a, b) = (finding.first.days, finding.second.days)
        switch finding.kind {
        case .sleep:
            if goal.goalType == .maximum, let threshold = finding.threshold {
                return "Based on \(days(a)) over \(amountText(threshold)) and \(days(b)) under."
            }
            return "Based on \(days(a)) with the goal met and \(days(b)) without."
        case .workouts: return "Based on \(a) workout \(a == 1 ? "day" : "days") and \(b) rest \(b == 1 ? "day" : "days")."
        case .activeEnergy: return "Based on \(days(a)) more active and \(days(b)) less active."
        }
    }

    // MARK: - Numbers

    func amountText(_ amount: Double) -> String {
        let digits = amount >= 10 ? 0 : 1
        return "\(amount.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))) \(unit)"
    }

    private func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }

    /// Minutes to the nearest five ("about 40 minutes"), at least 5.
    static func roundedMinutes(_ minutes: Double) -> Int { max(5, Int((minutes / 5).rounded()) * 5) }

    /// "6 h 35", "7 h", "45 min".
    static func sleepText(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let (hours, rest) = (total / 60, total % 60)
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(String(format: "%02d", rest))"
    }
}
