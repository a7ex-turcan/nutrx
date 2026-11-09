import Foundation
import SwiftData

/// How you feel's answers (#133, docs/pro/HOW-YOU-FEEL.md §2, §6): one per question and day. Two devices can each
/// write one before they sync; the newest `updatedAt` is the answer, and the next change on a day removes the rest.
/// The only writer of `FeelingAnswer`s.
enum FeelingAnswers {
    /// Days before today that History can still change: today and the 7 before it.
    static let editableDays = 7

    /// A question's answer about `day`.
    static func value(for question: FeelingQuestion, on day: Date, calendar: Calendar = .current) -> Int? {
        newest(of: question, on: day, calendar: calendar)?.value
    }

    /// The day's answers, by question.
    static func values(for questions: [FeelingQuestion], on day: Date,
                       calendar: Calendar = .current) -> [PersistentIdentifier: Int] {
        var values: [PersistentIdentifier: Int] = [:]
        for question in questions {
            if let value = value(for: question, on: day, calendar: calendar) {
                values[question.persistentModelID] = value
            }
        }
        return values
    }

    /// Answers a question for a day, or clears it with nil. Any other answer that day goes, so the day has one.
    static func set(_ value: Int?, for question: FeelingQuestion, on day: Date, in context: ModelContext,
                    calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        let sameDay = (question.answers ?? []).filter { calendar.isDate($0.day, inSameDayAs: start) }
            .sorted { $0.updatedAt > $1.updatedAt }
        if let value {
            if let keep = sameDay.first {
                keep.value = value
                keep.updatedAt = Date()
                sameDay.dropFirst().forEach(context.delete)
            } else {
                context.insert(FeelingAnswer(question: question, day: start, value: value))
            }
        } else {
            sameDay.forEach(context.delete)
        }
        try? context.save()
    }

    /// Every question has an answer.
    static func isComplete(_ questions: [FeelingQuestion], values: [PersistentIdentifier: Int]) -> Bool {
        !questions.isEmpty && questions.allSatisfy { values[$0.persistentModelID] != nil }
    }

    /// Whether Today shows "How was today?" at `now`: turned on, with questions, from the Ask from time until the day
    /// ends, unless its ✕ hid it today.
    static func cardShows(enabled: Bool, hasQuestions: Bool, askMinutes: Int, hiddenDay: Date?, now: Date,
                          calendar: Calendar = .current) -> Bool {
        guard enabled, hasQuestions else { return false }
        if let hiddenDay, calendar.isDate(hiddenDay, inSameDayAs: now) { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= askMinutes
    }

    /// History can change a day's answers from today back `editableDays` days; older days are read-only.
    static func isEditable(_ day: Date, today: Date = .now, calendar: Calendar = .current) -> Bool {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: day),
                                           to: calendar.startOfDay(for: today)).day ?? 0
        return (0...editableDays).contains(days)
    }

    /// The first day How you feel could have an answer: when its first question was made. History shows "How you
    /// felt" from then on.
    static func firstDay(of questions: [FeelingQuestion], calendar: Calendar = .current) -> Date? {
        questions.map(\.createdAt).min().map { calendar.startOfDay(for: $0) }
    }

    private static func newest(of question: FeelingQuestion, on day: Date, calendar: Calendar) -> FeelingAnswer? {
        (question.answers ?? []).filter { calendar.isDate($0.day, inSameDayAs: day) }
            .max { $0.updatedAt < $1.updatedAt }
    }
}
