import Foundation
import SwiftData

/// How you feel (#133, docs/pro/HOW-YOU-FEEL.md §6): a question's answer for one day. One per question and day;
/// if two devices answer the same day before they sync, the newest `updatedAt` is the answer.
@Model
final class FeelingAnswer {
    /// The start of the local day the answer is about.
    var day: Date = Date()
    /// 1–5 on a scale; 1 for yes and 0 for no.
    var value: Int = 0
    var updatedAt: Date = Date()
    var question: FeelingQuestion? = nil

    init(question: FeelingQuestion, day: Date, value: Int) {
        self.question = question
        self.day = day
        self.value = value
        self.updatedAt = Date()
    }
}
