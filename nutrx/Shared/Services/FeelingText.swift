import Foundation

/// How you feel's words (#133, docs/pro/HOW-YOU-FEEL.md): Settings → How you feel and its question sheet. Pure.
enum FeelingText {
    /// Under the switch.
    static let intro = "Each evening, Today asks how the day went, one tap per question. Your answers stay on "
        + "your devices and in your private iCloud, like your logs. nutrx never sees them."

    static let askFromFooter = "Today asks “How was today?” from this time until the day ends."

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
