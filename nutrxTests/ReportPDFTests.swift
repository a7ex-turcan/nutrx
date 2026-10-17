import PDFKit
import XCTest
@testable import nutrx

/// The report for your doctor as a PDF: one page per layout page, real (searchable) text, the chart's words.
final class ReportPDFTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    /// 16 July – 13 October: six nutrients logged every day but Sundays, a note each.
    private func report() -> DoctorReport {
        let goals: [(String, String, GoalType, Double, Double?)] = [
            ("Vitamin D", "IU", .minimum, 4000, nil), ("Omega-3", "mg", .minimum, 2000, nil),
            ("Magnesium", "mg", .minimum, 400, nil), ("Water", "L", .minimum, 2.5, nil),
            ("Protein", "g", .range, 120, 160), ("Caffeine", "mg", .maximum, 400, nil),
        ]
        let ids = goals.map { _ in UUID() }
        let nutrients = zip(ids, goals).map { id, goal in
            HistoryNutrient(id: id, goalType: goal.2, target: goal.3, upperBound: goal.4, createdAt: day(1, 1),
                            isRemoved: false)
        }
        var totals: [Date: [UUID: Double]] = [:]
        var date = day(7, 16)
        while date <= day(10, 13) {
            if calendar.component(.weekday, from: date) != 1 {
                totals[date] = Dictionary(uniqueKeysWithValues: zip(ids, goals).map { ($0, $1.3 * 1.1) })
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        let log = HistoryLog(nutrients: nutrients, totals: totals, today: day(10, 14), calendar: calendar)
        let names = Dictionary(uniqueKeysWithValues: zip(ids, goals.map(\.0)))
        let units = Dictionary(uniqueKeysWithValues: zip(ids, goals.map(\.1)))
        let notes = [DoctorReport.NoteEntry(date: day(8, 2), nutrientID: ids[0], text: "Switched to 2,000 IU softgels"),
                     DoctorReport.NoteEntry(date: day(9, 19), nutrientID: ids[1], text: "Stopped while travelling, 3 days"),
                     DoctorReport.NoteEntry(date: day(10, 6), nutrientID: ids[2], text: "Taking with dinner")]
        return DoctorReport.build(log: log, names: names, units: units, start: day(7, 16), end: day(10, 13),
                                  personName: "Alex", notes: notes)
    }

    func testThePDFHasEveryPageWithItsText() throws {
        let report = report()
        let layout = ReportLayout(report: report, paper: .a4)
        XCTAssertEqual(layout.pages.count, 4)
        let data = try ReportPDF.data(report: report, layout: layout, generatedOn: day(10, 14))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 4)
        let firstPage = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(firstPage.bounds(for: .mediaBox).size, CGSize(width: 595, height: 842))

        let cover = try XCTUnwrap(firstPage.string)
        for text in ["Intake report", "Alex", "Summary by nutrient", "Vitamin D", "Caffeine", "At most 400 mg",
                     "Between 120–160 g", "page 1 of 4", "Self-reported intake"] {
            XCTAssertTrue(cover.contains(text), "cover: \(text)")
        }
        let last = try XCTUnwrap(document.page(at: 3)?.string)
        for text in ["Protein", "Caffeine", "Notes", "Taking with dinner", "page 4 of 4", "Dashed line: limit."] {
            XCTAssertTrue(last.contains(text), "last page: \(text)")
        }
        XCTAssertEqual(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, "Intake report")
    }

    func testLetterPaper() throws {
        let report = report()
        let layout = ReportLayout(report: report, paper: .letter)
        let document = try XCTUnwrap(PDFDocument(data: try ReportPDF.data(report: report, layout: layout)))
        XCTAssertEqual(document.pageCount, layout.pages.count)
        XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, CGSize(width: 612, height: 792))
    }

    func testTheFileIsRemovedWithItsFolder() throws {
        let report = report()
        let url = try ReportPDF.write(report: report, layout: ReportLayout(report: report, paper: .a4))
        XCTAssertEqual(url.lastPathComponent, "nutrx-report-2026-07-16-to-2026-10-13.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        ReportPDF.remove(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    // MARK: - Chart words

    func testAxisLabelsNameTheEndsAndEachMonth() {
        let text = ReportText(report: report(), calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.axisLabels().map(\.text), ["16 Jul", "Aug", "Sep", "Oct", "13 Oct"])
        XCTAssertEqual(text.axisLabels().map(\.index), [0, 16, 47, 77, 89])
    }

    func testAMonthTooCloseToAnEndIsLeftOut() {
        // 22 September – 1 October: the 1st is the last day, so it gets the day label, not a month label beside it.
        let base = report()
        let days = (0..<10).map { calendar.date(byAdding: .day, value: $0, to: day(9, 22))! }
        let short = DoctorReport(start: days[0], end: days[9], name: nil, sections: base.sections, notes: [],
                                 daysWithEntries: 0, overallHitRate: nil, longestStreak: 0, days: days)
        let text = ReportText(report: short, calendar: calendar, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(text.axisLabels().map(\.text), ["22 Sep", "1 Oct"])
    }

    func testCaptionsAndGoalLines() throws {
        let report = report()
        let text = ReportText(report: report, calendar: calendar, locale: Locale(identifier: "en_GB"))
        let vitaminD = try XCTUnwrap(report.sections.first)
        XCTAssertEqual(text.goalLine(vitaminD), "Goal: at least 4,000 IU")
        XCTAssertEqual(ReportText.chartCaption(.range, hasUpperBound: true),
                       "Daily totals. Dark bars were in range; light bars weren't. Dashed lines: range.")
        XCTAssertEqual(text.dates, "16 July – 13 October 2026")
    }
}
