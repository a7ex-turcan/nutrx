import Foundation
import SwiftData

/// Settings → Export data (docs/pro/design/1-stacks-export: export): the user's intake history as a CSV file, one
/// row per entry, made on the device. Spreadsheet-friendly on purpose: ISO dates, 24-hour times, plain numbers.
enum ExportService {
    enum Period: String, CaseIterable, Identifiable {
        case allTime
        case last30Days
        case last90Days

        var id: Self { self }

        var title: String {
            switch self {
            case .allTime: "All time"
            case .last30Days: "Last 30 days"
            case .last90Days: "Last 90 days"
            }
        }

        /// The first moment included: the start of the day N − 1 days ago (so "Last 30 days" is today and the 29
        /// days before it), or nil for all time.
        func start(now: Date, calendar: Calendar = .current) -> Date? {
            let days: Int
            switch self {
            case .allTime: return nil
            case .last30Days: days = 30
            case .last90Days: days = 90
            }
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -(days - 1), to: today)
        }
    }

    /// One CSV row's worth of an `IntakeRecord`, so the CSV can be built and tested without a store.
    struct Entry: Equatable {
        let date: Date
        let nutrient: String
        let amount: Double
        let unit: String
        let note: String?
    }

    /// What the screen shows under the period picker: "1,284 entries · 6 nutrients · since 2 March 2026".
    struct Summary: Equatable {
        let entryCount: Int
        let nutrientCount: Int
        let earliest: Date?
    }

    static let header = ["date", "time", "nutrient", "amount", "unit", "note"]

    /// One row of How you feel's file (#133, docs/pro/HOW-YOU-FEEL.md §5): a question's answer for a day.
    struct FeelingEntry: Equatable {
        let day: Date
        let question: String
        /// "4", or "yes" / "no".
        let answer: String
        /// "1–5" or "yes/no".
        let scale: String
    }

    static let feelingsHeader = ["date", "question", "answer", "scale"]

    // MARK: - Fetching

    /// The period's entries, most recent first. Includes nutrients deleted since (it's the user's history) and
    /// skips records whose nutrient is gone for good.
    @MainActor
    static func entries(for period: Period, context: ModelContext, now: Date = .now) -> [Entry] {
        var descriptor = FetchDescriptor<IntakeRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let start = period.start(now: now) {
            descriptor.predicate = #Predicate { $0.date >= start }
        }
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let nutrient = record.nutrient else { return nil }
            return Entry(date: record.date, nutrient: nutrient.name, amount: record.amount, unit: nutrient.unit,
                         note: record.note)
        }
    }

    /// How you feel's answers in the period, most recent day first and then in the questions' order; removed
    /// questions' too. One per question and day, the newest.
    @MainActor
    static func feelingEntries(for period: Period, context: ModelContext, now: Date = .now,
                               calendar: Calendar = .current) -> [FeelingEntry] {
        let start = period.start(now: now, calendar: calendar)
        var rows: [(day: Date, order: Int, entry: FeelingEntry)] = []
        for (order, question) in FeelingQuestions.all(in: context).enumerated() {
            let days = Set((question.answers ?? []).map { calendar.startOfDay(for: $0.day) })
            for day in days where start.map({ day >= $0 }) ?? true {
                guard let value = FeelingAnswers.value(for: question, on: day, calendar: calendar) else { continue }
                rows.append((day, order, FeelingEntry(
                    day: day, question: question.displayTitle,
                    answer: question.kind == .scale ? "\(value)" : (value == 1 ? "yes" : "no"),
                    scale: question.kind == .scale ? "1–5" : "yes/no")))
            }
        }
        return rows.sorted { $0.day != $1.day ? $0.day > $1.day : $0.order < $1.order }.map(\.entry)
    }

    static func summary(of entries: [Entry]) -> Summary {
        Summary(entryCount: entries.count,
                nutrientCount: Set(entries.map(\.nutrient)).count,
                earliest: entries.map(\.date).min())
    }

    /// "1,284 entries · 6 nutrients · since 2 March 2026", or "No entries in this period".
    static func summaryText(_ summary: Summary, locale: Locale = .current) -> String {
        guard summary.entryCount > 0, let earliest = summary.earliest else { return "No entries in this period" }
        let entries = summary.entryCount == 1 ? "1 entry" : "\(summary.entryCount.formatted(.number.locale(locale))) entries"
        let nutrients = summary.nutrientCount == 1 ? "1 nutrient" : "\(summary.nutrientCount) nutrients"
        let since = earliest.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
        return "\(entries) · \(nutrients) · since \(since)"
    }

    // MARK: - CSV

    /// RFC 4180 CSV: a header row, CRLF line ends, fields quoted when they hold a comma, quote or line break.
    /// Starts with a UTF-8 byte order mark so Excel reads "µg" and accents correctly (Numbers and Google Sheets
    /// ignore it).
    static func csv(_ entries: [Entry], timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var lines = [header.joined(separator: ",")]
        for entry in entries {
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
            let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
            let fields = [date, time, text(entry.nutrient), number(entry.amount), text(entry.unit),
                          text(entry.note ?? "")]
            lines.append(fields.map(escaped).joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// How you feel's file: the same quoting, BOM and formula guard as the log.
    static func feelingsCSV(_ entries: [FeelingEntry], timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var lines = [feelingsHeader.joined(separator: ",")]
        for entry in entries {
            let parts = calendar.dateComponents([.year, .month, .day], from: entry.day)
            let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            lines.append([date, text(entry.question), entry.answer, entry.scale].map(escaped).joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// "nutrx-how-you-feel-2026-11-08.csv".
    static func feelingsFileName(now: Date = .now, timeZone: TimeZone = .current) -> String {
        fileName(now: now, timeZone: timeZone).replacingOccurrences(of: "nutrx-export-", with: "nutrx-how-you-feel-")
    }

    /// "nutrx-export-2026-10-14.csv", in the user's own calendar day.
    static func fileName(now: Date = .now, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "nutrx-export-%04d-%02d-%02d.csv", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Where exports are written: `tmp/nutrx-export/<uuid>/<file name>`.
    static var exportsFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("nutrx-export", isDirectory: true)
    }

    /// Writes the CSV to a fresh folder for the share sheet. The caller removes it once the sheet is done
    /// (`removeExport`), so no copy stays on the device; and every export first clears what an earlier one left
    /// behind (the app was killed with the share sheet up, so `onDismiss` never ran).
    static func writeExport(_ csv: String, fileName: String) throws -> URL {
        try writeExport([(csv, fileName)])[0]
    }

    /// Several files in one fresh folder: the log, and How you feel's answers when there are any (#133).
    static func writeExport(_ files: [(csv: String, fileName: String)]) throws -> [URL] {
        try? FileManager.default.removeItem(at: exportsFolder)
        let folder = exportsFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try files.map { file in
            let url = folder.appendingPathComponent(file.fileName)
            try Data(file.csv.utf8).write(to: url, options: .atomic)
            return url
        }
    }

    static func removeExport(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Fields

    /// Plain digits with a "." decimal and no grouping, whatever the locale, so every spreadsheet reads it as a
    /// number. Decrements stay negative.
    static func number(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...6)))
    }

    /// Text a spreadsheet would run as a formula (=, +, -, @, tab, return first) gets a leading apostrophe, as
    /// OWASP recommends for CSV files. Only names, units and notes, never the numbers.
    static func text(_ value: String) -> String {
        // Scalars, not Characters: "\r\n" is a single Character in Swift.
        guard let first = value.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first) else { return value }
        return "'" + value
    }

    static func escaped(_ field: String) -> String {
        guard field.unicodeScalars.contains(where: { ",\"\n\r".unicodeScalars.contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
