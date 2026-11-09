import Foundation
import SwiftData

/// How you feel's words (#133, docs/pro/HOW-YOU-FEEL.md): Settings → How you feel, its question sheet, Today's card
/// and History's answers. Pure.
enum FeelingText {
    static let cardTitle = "How was today?"

    /// The reminder's body: the questions in order, as a list for the locale, the first three then a count ("Check
    /// in on Energy, Mood, Sleep last night and 2 more.").
    static func reminderBody(_ titles: [String], locale: Locale = .current) -> String {
        guard !titles.isEmpty else { return "Check in with nutrx." }
        var shown = Array(titles.prefix(3))
        if titles.count > 3 { shown.append("\(titles.count - 3) more") }
        let formatter = ListFormatter()
        formatter.locale = locale
        return "Check in on \(formatter.string(from: shown) ?? shown.joined(separator: ", "))."
    }
    static let historyTitle = "How you felt"
    static let noCheckIn = "No check-in"

    /// An answer as it reads: "4", "Yes", "No".
    static func answer(_ value: Int, kind: FeelingKind) -> String {
        switch kind {
        case .scale: "\(value)"
        case .yesNo: value == 1 ? "Yes" : "No"
        }
    }

    /// What VoiceOver reads for a scale: "4 of 5", or "Not answered".
    static func scaleValue(_ value: Int?) -> String {
        value.map { "\($0) of 5" } ?? "Not answered"
    }

    /// The folded card: "Checked in · Energy 4 · Mood 3 · Headache no".
    static func checkedIn(_ questions: [FeelingQuestion], values: [PersistentIdentifier: Int]) -> String {
        "Checked in · \(summary(questions, values: values))"
    }

    /// The answers' line: "Energy 4 · Mood 3 · Headache no", in the questions' order, answered ones only.
    static func summary(_ questions: [FeelingQuestion], values: [PersistentIdentifier: Int]) -> String {
        questions.compactMap { question in
            values[question.persistentModelID].map { "\(question.displayTitle) \(answer($0, kind: question.kind).lowercased())" }
        }
        .joined(separator: " · ")
    }

    /// Under the switch.
    static let intro = "From the time you set, Today asks how the day went, one tap per question. Your answers stay "
        + "on your devices and in your private iCloud, like your logs. nutrx never sees them."

    static let askFromFooter = "Today asks “How was today?” from this time until the day ends. Remind me sends a "
        + "notification then, unless you've already checked in."

    static let questionsFooter = "Drag to reorder. Swipe to remove a question; its answers stay in History."

    /// The "Your own question" row's caption.
    static let ownCaption = "1 to 5, or yes or no"

    static func kindName(_ kind: FeelingKind) -> String {
        switch kind {
        case .scale: "1 to 5"
        case .yesNo: "Yes or no"
        }
    }

    /// The row's caption: "1 to 5 · Low to High", "Yes or no".
    static func caption(_ question: FeelingQuestion) -> String {
        caption(kind: question.kind, ends: question.ends)
    }

    static func caption(kind: FeelingKind, ends: (low: String, high: String)) -> String {
        switch kind {
        case .scale: "\(kindName(.scale)) · \(ends.low) to \(ends.high)"
        case .yesNo: kindName(.yesNo)
        }
    }

    /// Under the presets left to add and "Your own question".
    static func addFooter(ownCount: Int) -> String {
        ownCount >= FeelingQuestions.ownLimit
            ? "You have \(FeelingQuestions.ownLimit) of your own. Remove one to add another."
            : "Up to \(FeelingQuestions.ownLimit) of your own, each 1 to 5 or yes or no."
    }

    /// The question sheet's note when the title can't be used. Nil for an empty title, which just disables Add.
    static func titleProblem(_ problem: FeelingQuestions.TitleProblem?) -> String? {
        problem == .duplicate ? "You already have a question called that." : nil
    }

    /// Under the kind picker in the question sheet.
    static func kindExplanation(_ kind: FeelingKind) -> String {
        switch kind {
        case .scale: "Answered from 1, low, to 5, high."
        case .yesNo: "Answered with Yes or No."
        }
    }

    /// Under the kind picker once the question has answers.
    static func kindLocked(_ kind: FeelingKind) -> String {
        "It has answers, so it stays \(kind == .scale ? "1 to 5" : "yes or no")."
    }
}
