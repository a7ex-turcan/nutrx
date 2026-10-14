import XCTest
import SwiftData
@testable import nutrx

/// CSV export: the file's format (header, quoting, numbers, dates), which records a period includes, the summary line.
@MainActor
final class ExportServiceTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let enUS = Locale(identifier: "en_US")

    /// 2026-10-14 08:05 UTC.
    private let morning = Date(timeIntervalSince1970: 1_791_965_100)

    private func entry(_ nutrient: String = "Vitamin D", amount: Double = 2000, unit: String = "IU",
                       note: String? = nil, date: Date? = nil) -> ExportService.Entry {
        ExportService.Entry(date: date ?? morning, nutrient: nutrient, amount: amount, unit: unit, note: note)
    }

    // MARK: - CSV format

    func testHeaderRowsBOMAndCRLF() {
        let csv = ExportService.csv([entry(note: "with breakfast")], timeZone: utc)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"), "UTF-8 BOM so Excel reads accents and µ")
        XCTAssertEqual(csv.dropFirst(), "date,time,nutrient,amount,unit,note\r\n2026-10-14,08:05,Vitamin D,2000,IU,with breakfast\r\n")
    }

    func testAnEmptyExportIsJustTheHeader() {
        XCTAssertEqual(ExportService.csv([], timeZone: utc), "\u{FEFF}date,time,nutrient,amount,unit,note\r\n")
    }

    func testFieldsWithCommasQuotesAndLineBreaksAreQuoted() {
        XCTAssertEqual(ExportService.escaped("plain"), "plain")
        XCTAssertEqual(ExportService.escaped("a, b"), "\"a, b\"")
        XCTAssertEqual(ExportService.escaped("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(ExportService.escaped("two\nlines"), "\"two\nlines\"")
        XCTAssertEqual(ExportService.escaped("crlf\r\nline"), "\"crlf\r\nline\"", "\\r\\n is one Character in Swift")
    }

    func testANoteWithACommaStaysOneField() {
        let csv = ExportService.csv([entry(note: "after lunch, with water")], timeZone: utc)
        XCTAssertTrue(csv.contains(",IU,\"after lunch, with water\"\r\n"))
    }

    func testNumbersArePlainWhateverTheLocale() {
        XCTAssertEqual(ExportService.number(2000), "2000")
        XCTAssertEqual(ExportService.number(0.25), "0.25")
        XCTAssertEqual(ExportService.number(1234.5), "1234.5")
        XCTAssertEqual(ExportService.number(-100), "-100", "decrements stay negative")
    }

    func testFormulaLikeTextIsDefusedButNumbersAreNot() {
        XCTAssertEqual(ExportService.text("=SUM(A1)"), "'=SUM(A1)")
        XCTAssertEqual(ExportService.text("+1"), "'+1")
        XCTAssertEqual(ExportService.text("-ish"), "'-ish")
        XCTAssertEqual(ExportService.text("@home"), "'@home")
        XCTAssertEqual(ExportService.text("Omega-3"), "Omega-3")
        let csv = ExportService.csv([entry(amount: -1000, note: "=oops")], timeZone: utc)
        XCTAssertTrue(csv.contains(",-1000,IU,'=oops\r\n"))
    }

    func testTimesAreTwentyFourHourInTheGivenTimeZone() {
        let evening = morning.addingTimeInterval(12 * 3600)  // 20:05 UTC
        let csv = ExportService.csv([entry(date: evening)], timeZone: TimeZone(identifier: "Europe/Bucharest")!)
        XCTAssertTrue(csv.contains("\r\n2026-10-14,23:05,"), csv)
    }

    func testFileNameUsesTheLocalDay() {
        XCTAssertEqual(ExportService.fileName(now: morning, timeZone: utc), "nutrx-export-2026-10-14.csv")
        let lateEvening = Date(timeIntervalSince1970: 1_792_018_800)  // 2026-10-14 23:00 UTC
        XCTAssertEqual(ExportService.fileName(now: lateEvening, timeZone: TimeZone(identifier: "Asia/Tokyo")!),
                       "nutrx-export-2026-10-15.csv")
    }

    // MARK: - Periods and fetching

    func testPeriodsStartAtTheStartOfTheirFirstDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        XCTAssertNil(ExportService.Period.allTime.start(now: .now))
        XCTAssertEqual(ExportService.Period.last30Days.start(now: .now), calendar.date(byAdding: .day, value: -29, to: today))
        XCTAssertEqual(ExportService.Period.last90Days.start(now: .now), calendar.date(byAdding: .day, value: -89, to: today))
    }

    func testEntriesAreNewestFirstWithinThePeriodIncludingDeletedNutrients() throws {
        let container = try ModelContainer.inMemoryForTests()
        let context = container.mainContext
        let vitaminD = Nutrient(name: "Vitamin D", unit: "IU", step: 1000, dailyTarget: 4000, sortOrder: 0)
        let caffeine = Nutrient(name: "Caffeine", unit: "mg", step: 100, dailyTarget: 400, sortOrder: 1, isDeleted: true)
        context.insert(vitaminD)
        context.insert(caffeine)
        let now = Date()
        let calendar = Calendar.current
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 1000, date: now.addingTimeInterval(-60), note: "latest"))
        context.insert(IntakeRecord(nutrient: caffeine, amount: 100, date: calendar.date(byAdding: .day, value: -10, to: now)!))
        context.insert(IntakeRecord(nutrient: vitaminD, amount: 2000, date: calendar.date(byAdding: .day, value: -45, to: now)!))
        try context.save()

        let all = ExportService.entries(for: .allTime, context: context, now: now)
        XCTAssertEqual(all.map(\.amount), [1000, 100, 2000])
        XCTAssertEqual(all.first?.note, "latest")
        XCTAssertEqual(all[1].nutrient, "Caffeine", "a nutrient deleted since is still the user's history")
        XCTAssertEqual(all[1].unit, "mg")

        XCTAssertEqual(ExportService.entries(for: .last30Days, context: context, now: now).map(\.amount), [1000, 100])
        XCTAssertEqual(ExportService.entries(for: .last90Days, context: context, now: now).count, 3)
    }

    // MARK: - Summary

    func testSummaryCountsEntriesNutrientsAndTheEarliestDay() {
        let earlier = morning.addingTimeInterval(-3 * 86_400)
        let summary = ExportService.summary(of: [entry(), entry("Omega-3", unit: "mg"), entry(date: earlier)])
        XCTAssertEqual(summary, ExportService.Summary(entryCount: 3, nutrientCount: 2, earliest: earlier))
    }

    func testSummaryText() {
        let march2 = Date(timeIntervalSince1970: 1_772_445_600)  // 2026-03-02 10:00 UTC
        XCTAssertEqual(ExportService.summaryText(.init(entryCount: 1284, nutrientCount: 6, earliest: march2), locale: enUS),
                       "1,284 entries · 6 nutrients · since March 2, 2026")
        XCTAssertEqual(ExportService.summaryText(.init(entryCount: 1, nutrientCount: 1, earliest: march2), locale: enUS),
                       "1 entry · 1 nutrient · since March 2, 2026")
        XCTAssertEqual(ExportService.summaryText(.init(entryCount: 0, nutrientCount: 0, earliest: nil), locale: enUS),
                       "No entries in this period")
    }

    // MARK: - File

    func testTheFileIsWrittenAndRemovedWithItsFolder() throws {
        let url = try ExportService.writeExport("date\r\n", fileName: "nutrx-export-2026-10-14.csv")
        XCTAssertEqual(url.lastPathComponent, "nutrx-export-2026-10-14.csv")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "date\r\n")
        ExportService.removeExport(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }
}
