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

    /// "nutrx-export-2026-10-14.csv", in the user's own calendar day.
    static func fileName(now: Date = .now, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "nutrx-export-%04d-%02d-%02d.csv", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Writes the CSV to a fresh folder in the temporary directory, for the share sheet. The caller removes the
    /// folder once the sheet is done (`removeExport`), so no copy stays on the device.
    static func writeExport(_ csv: String, fileName: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
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
