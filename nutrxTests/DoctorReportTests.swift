import XCTest
@testable import nutrx

/// The report for your doctor: the facts for a period, the words, and how it falls onto pages.
final class DoctorReportTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private let vitaminD = UUID()
    private let caffeine = UUID()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private var nutrients: [HistoryNutrient] {
        [HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil, createdAt: day(9, 1), isDeleted: false),
         HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil, createdAt: day(9, 1), isDeleted: false)]
    }

    private var names: [UUID: String] { [vitaminD: "Vitamin D", caffeine: "Caffeine"] }
    private var units: [UUID: String] { [vitaminD: "IU", caffeine: "mg"] }

    /// 1–10 October: Vitamin D met on 7 days (missed on 3, 4 and 5), caffeine always under its limit; nothing logged
    /// on 6 October.
    private func report(notes: [DoctorReport.NoteEntry] = [], nutrientIDs: [UUID]? = nil) -> DoctorReport {
        var totals: [Date: [UUID: Double]] = [:]
        for d in 1...10 where d != 6 {
            totals[day(10, d)] = [vitaminD: [3, 4, 5].contains(d) ? 1000 : 4000, caffeine: 200]
        }
        let log = HistoryLog(nutrients: nutrients, totals: totals, today: day(10, 15), calendar: calendar)
        return DoctorReport.build(log: log, names: names, units: units, start: day(10, 1), end: day(10, 10),
                                  nutrientIDs: nutrientIDs, personName: " Alex ", notes: notes)
    }

    // MARK: - Facts

    func testTheFactsCountOnlyLoggedDays() throws {
        let report = report()
        XCTAssertEqual(report.dayCount, 10)
        XCTAssertEqual(report.daysWithEntries, 9, "nothing logged on 6 October")
        let d = try XCTUnwrap(report.sections.first { $0.id == vitaminD })
        XCTAssertEqual(d.countedDays, 9, "an unlogged day is unknown, not missed")
        XCTAssertEqual(d.metDays, 6)
        XCTAssertEqual(d.hitRate!, 6.0 / 9, accuracy: 0.001)
        XCTAssertEqual(d.average!, (6 * 4000.0 + 3 * 1000) / 9, accuracy: 0.01)
        XCTAssertNil(d.days[5].total, "6 October")
        XCTAssertEqual(report.overallHitRate!, 15.0 / 18, accuracy: 0.001, "6 + 9 of 9 + 9")
        XCTAssertEqual(report.longestStreak, 4, "7–10 October; the unlogged 6th breaks it")
        XCTAssertEqual(report.name, "Alex")
    }

    func testThePeriodEndsYesterdayAtTheLatest() {
        var totals: [Date: [UUID: Double]] = [:]
        totals[day(10, 14)] = [vitaminD: 4000]
        let log = HistoryLog(nutrients: nutrients, totals: totals, today: day(10, 15), calendar: calendar)
        let report = DoctorReport.build(log: log, names: names, units: units, start: day(10, 10), end: day(10, 15))
        XCTAssertEqual(report.end, day(10, 14))
        let last30 = DoctorReport.lastDays(30, today: day(10, 15), calendar: calendar)
        XCTAssertEqual(last30.start, day(9, 15))
        XCTAssertEqual(last30.end, day(10, 14))
    }

    func testChosenNutrientsAndTheirNotes() {
        let notes = [DoctorReport.NoteEntry(date: day(10, 8), nutrientID: caffeine, text: "Decaf from now on"),
                     DoctorReport.NoteEntry(date: day(10, 2), nutrientID: vitaminD, text: "Switched to 2,000 IU softgels"),
                     DoctorReport.NoteEntry(date: day(9, 20), nutrientID: vitaminD, text: "Before the period")]
        let all = report(notes: notes)
        XCTAssertEqual(all.notes.map(\.text), ["Switched to 2,000 IU softgels", "Decaf from now on"], "in the period, by date")
        let onlyD = report(notes: notes, nutrientIDs: [vitaminD])
        XCTAssertEqual(onlyD.sections.map(\.name), ["Vitamin D"])
        XCTAssertEqual(onlyD.notes.map(\.nutrientName), ["Vitamin D"])
        let onlyCaffeine = report(nutrientIDs: [caffeine])
        XCTAssertEqual(onlyCaffeine.longestStreak, 5, "Vitamin D's misses on the 3rd–5th don't break a caffeine-only report")
        XCTAssertEqual(onlyCaffeine.overallHitRate, 1)
    }

    // MARK: - Words

    func testWords() throws {
        let text = ReportText(report: report(), calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text.period, "October 1 – October 10, 2026 · 10 days")
        XCTAssertEqual(text.daysWithEntries, "9 of 10")
        XCTAssertEqual(text.percent(0.8333), "83%")
        XCTAssertEqual(text.percent(nil), "—")
        XCTAssertEqual(text.longestStreak, "4 days")
        let d = try XCTUnwrap(text.report.sections.first)
        XCTAssertEqual(text.goal(d), "At least 4,000 IU")
        let range = DoctorReport.Section(id: UUID(), name: "Protein", unit: "g", goalType: .range, target: 120,
                                         upperBound: 160, days: [], countedDays: 0, metDays: 0, daysLogged: 0, average: nil)
        XCTAssertEqual(text.goal(range), "Between 120–160 g")
        XCTAssertEqual(text.average(range), "—")
        XCTAssertEqual(text.generated(on: day(10, 14)), "Generated by nutrx on Oct 14, 2026")
        XCTAssertEqual(ReportText.pageNumber(2, of: 4), "page 2 of 4")
        XCTAssertEqual(text.fileName, "nutrx-report-2026-10-01-to-2026-10-10.pdf")
    }

    // MARK: - Pages

    private func manySections(_ count: Int, trends: Int = 0) -> [DoctorReport.Section] {
        (0..<count).map { index in
            var section = DoctorReport.Section(id: UUID(), name: "N\(index)", unit: "mg", goalType: .minimum, target: 1,
                                               upperBound: nil, days: [], countedDays: 0, metDays: 0, daysLogged: 0,
                                               average: nil)
            section.trends = Array(repeating: "A trend.", count: trends)
            return section
        }
    }

    private func fixture(sections: Int, notes: Int, trends: Int = 0) -> DoctorReport {
        DoctorReport(start: day(10, 1), end: day(10, 10), name: nil, sections: manySections(sections, trends: trends),
                     notes: (0..<notes).map { DoctorReport.Note(date: day(10, 1), nutrientName: "N", text: "Note \($0)") },
                     daysWithEntries: 0, overallHitRate: nil, longestStreak: 0, days: [])
    }

    func testTheDesignsFourPages() {
        // Six nutrients and three notes on A4: the whole summary on the cover, two sections a page, the notes under
        // the last two ("page 1 of 4").
        let layout = ReportLayout(report: fixture(sections: 6, notes: 3), paper: .a4)
        let expected: [ReportLayout.Page] = [
            .cover(summaryRows: 0..<6),
            .content([.section(0), .section(1)]),
            .content([.section(2), .section(3)]),
            .content([.section(4), .section(5), .notesHeader, .notes(0..<3)]),
        ]
        XCTAssertEqual(layout.pages, expected)
    }

    func testALongListOfNutrientsContinuesTheSummary() {
        let layout = ReportLayout(report: fixture(sections: 12, notes: 0), paper: .a4)
        guard case .cover(let rows) = layout.pages[0], case .summary(let more) = layout.pages[1] else {
            return XCTFail("expected the cover, then a summary page")
        }
        XCTAssertEqual(rows.upperBound, more.lowerBound)
        XCTAssertEqual(more.upperBound, 12)
    }

    func testEveryBlockAppearsOnceAndInOrder() {
        for paper in [ReportLayout.Paper.a4, .letter] {
            for (sections, notes, trends) in [(1, 0, 0), (6, 3, 0), (13, 40, 0), (5, 90, 2), (25, 0, 1)] {
                let report = fixture(sections: sections, notes: notes, trends: trends)
                let layout = ReportLayout(report: report, paper: paper)
                var summaryRows: [Int] = []
                var sectionOrder: [Int] = []
                var noteOrder: [Int] = []
                for page in layout.pages {
                    switch page {
                    case .cover(let rows), .summary(let rows): summaryRows += Array(rows)
                    case .content(let blocks):
                        var used: CGFloat = 0
                        for block in blocks {
                            switch block {
                            case .section(let i):
                                sectionOrder.append(i)
                                used += ReportLayout.blockHeight(report.sections[i])
                            case .notesHeader: used += ReportLayout.notesHeaderHeight
                            case .notes(let range):
                                noteOrder += Array(range)
                                used += range.reduce(0) { $0 + ReportLayout.noteHeight(report.notes[$1], paper: paper) }
                            }
                        }
                        XCTAssertLessThanOrEqual(used, ReportLayout.contentHeight(paper), "\(paper) \(sections)/\(notes): a page overflows")
                    }
                }
                XCTAssertEqual(summaryRows, Array(0..<sections))
                XCTAssertEqual(sectionOrder, Array(0..<sections))
                XCTAssertEqual(noteOrder, Array(0..<notes))
            }
        }
    }

    func testANotesHeaderNeverEndsAPage() {
        let layout = ReportLayout(report: fixture(sections: 4, notes: 30), paper: .letter)
        for page in layout.pages {
            if case .content(let blocks) = page, blocks.last == .notesHeader {
                XCTFail("a notes header with no rows under it")
            }
        }
    }

    func testLongNotesTakeMoreRoomAndStillFit() {
        let long = String(repeating: "Took it with breakfast instead of dinner. ", count: 6)
        var report = fixture(sections: 2, notes: 0)
        report = DoctorReport(start: report.start, end: report.end, name: nil, sections: report.sections,
                              notes: (0..<25).map { DoctorReport.Note(date: day(10, 1), nutrientName: "N", text: $0 % 2 == 0 ? long : "Short") },
                              daysWithEntries: 0, overallHitRate: nil, longestStreak: 0, days: [])
        XCTAssertEqual(ReportLayout.noteHeight(report.notes[0], paper: .a4),
                       ReportLayout.noteRowHeight + 2 * ReportLayout.noteLineHeight, "capped at three lines")
        XCTAssertEqual(ReportLayout.noteHeight(report.notes[1], paper: .a4), ReportLayout.noteRowHeight)
        let layout = ReportLayout(report: report, paper: .a4)
        for page in layout.pages {
            guard case .content(let blocks) = page else { continue }
            let used = blocks.reduce(CGFloat(0)) { total, block in
                switch block {
                case .section(let i): total + ReportLayout.blockHeight(report.sections[i])
                case .notesHeader: total + ReportLayout.notesHeaderHeight
                case .notes(let r): total + r.reduce(0) { $0 + ReportLayout.noteHeight(report.notes[$1], paper: .a4) }
                }
            }
            XCTAssertLessThanOrEqual(used, ReportLayout.contentHeight(.a4))
        }
    }

    func testAnEmptyPeriodReadsAsNoDays() {
        let log = HistoryLog(nutrients: nutrients, totals: [:], today: day(10, 15), calendar: calendar)
        let report = DoctorReport.build(log: log, names: names, units: units, start: day(10, 20), end: day(10, 25))
        XCTAssertEqual(report.dayCount, 0)
        XCTAssertNil(report.overallHitRate)
    }

    func testANetZeroDayStillCountsAsLogged() {
        let log = HistoryLog(nutrients: nutrients, totals: [day(10, 2): [vitaminD: 0]], today: day(10, 15), calendar: calendar)
        let report = DoctorReport.build(log: log, names: names, units: units, start: day(10, 1), end: day(10, 3),
                                        nutrientIDs: [vitaminD])
        XCTAssertEqual(report.sections.first?.daysLogged, 1, "logged, then taken back off")
    }

    func testPaperFollowsTheRegion() {
        XCTAssertEqual(ReportLayout.Paper.forRegion("US"), .letter)
        XCTAssertEqual(ReportLayout.Paper.forRegion("CA"), .letter)
        XCTAssertEqual(ReportLayout.Paper.forRegion("GB"), .a4)
        XCTAssertEqual(ReportLayout.Paper.forRegion("RO"), .a4)
        XCTAssertEqual(ReportLayout.Paper.forRegion(nil), .a4)
        XCTAssertEqual(ReportLayout.Paper.a4.size, CGSize(width: 595, height: 842))
    }
}
