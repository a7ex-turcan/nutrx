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
        [HistoryNutrient(id: vitaminD, goalType: .minimum, target: 4000, upperBound: nil, createdAt: day(9, 1), isRemoved: false),
         HistoryNutrient(id: caffeine, goalType: .maximum, target: 400, upperBound: nil, createdAt: day(9, 1), isRemoved: false)]
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

    private func fixture(sections: Int, notes: Int, trends: Int = 0, feelings: Int = 0,
                         patterns: Int = 0) -> DoctorReport {
        DoctorReport(start: day(10, 1), end: day(10, 10), name: nil, sections: manySections(sections, trends: trends),
                     notes: (0..<notes).map { DoctorReport.Note(date: day(10, 1), nutrientName: "N", text: "Note \($0)") },
                     daysWithEntries: 0, overallHitRate: nil, longestStreak: 0, days: [],
                     feelings: (0..<feelings).map {
                         DoctorReport.Feeling(title: "Q\($0)", kind: .scale, average: 3, yesDays: 0, answeredDays: 5,
                                              lowWord: "Low", highWord: "High")
                     },
                     feelingPatterns: (0..<patterns).map { "Pattern \($0)." })
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
            let cases = [(1, 0, 0, 0, 0), (6, 3, 0, 3, 2), (13, 40, 0, 8, 6), (5, 90, 2, 13, 20), (25, 0, 1, 2, 0),
                         (2, 0, 0, 40, 40)]
            for (sections, notes, trends, feelings, patterns) in cases {
                let report = fixture(sections: sections, notes: notes, trends: trends, feelings: feelings,
                                     patterns: patterns)
                let layout = ReportLayout(report: report, paper: paper)
                var summaryRows: [Int] = []
                var sectionOrder: [Int] = []
                var feelingOrder: [Int] = []
                var patternOrder: [Int] = []
                var noteOrder: [Int] = []
                // Sections, then How you felt, then its patterns, then the notes.
                var kinds: [Int] = []
                for page in layout.pages {
                    switch page {
                    case .cover(let rows), .summary(let rows): summaryRows += Array(rows)
                    case .content(let blocks):
                        for block in blocks {
                            switch block {
                            case .section(let i): sectionOrder.append(i); kinds.append(0)
                            case .feelingsHeader, .feelings: kinds.append(1)
                            case .feelingPatternsHeader, .feelingPatterns: kinds.append(2)
                            case .notesHeader, .notes: kinds.append(3)
                            }
                            if case .feelings(let range) = block { feelingOrder += Array(range) }
                            if case .feelingPatterns(let range) = block { patternOrder += Array(range) }
                            if case .notes(let range) = block { noteOrder += Array(range) }
                        }
                        let used = blocks.reduce(CGFloat(0)) {
                            $0 + ReportLayout.height(of: $1, in: report, paper: paper)
                        }
                        XCTAssertLessThanOrEqual(used, ReportLayout.contentHeight(paper), "\(paper) \(sections)/\(notes): a page overflows")
                    }
                }
                XCTAssertEqual(summaryRows, Array(0..<sections))
                XCTAssertEqual(sectionOrder, Array(0..<sections))
                XCTAssertEqual(feelingOrder, Array(0..<feelings))
                XCTAssertEqual(patternOrder, Array(0..<patterns))
                XCTAssertEqual(noteOrder, Array(0..<notes))
                XCTAssertEqual(kinds, kinds.sorted())
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

    /// How you felt (#133) comes after the sections and before the notes, with its patterns under its rows; neither
    /// header ends a page.
    func testHowYouFeltSitsBetweenTheSectionsAndTheNotes() {
        let layout = ReportLayout(report: fixture(sections: 1, notes: 2, feelings: 3, patterns: 2), paper: .a4)
        XCTAssertEqual(layout.pages, [
            .cover(summaryRows: 0..<1),
            .content([.section(0), .feelingsHeader, .feelings(0..<3), .feelingPatternsHeader, .feelingPatterns(0..<2),
                      .notesHeader, .notes(0..<2)]),
        ])
        for (sections, feelings) in [(2, 1), (3, 13), (2, 30)] {
            for paper in [ReportLayout.Paper.a4, .letter] {
                let report = fixture(sections: sections, notes: 0, feelings: feelings, patterns: 4)
                let layout = ReportLayout(report: report, paper: paper)
                for page in layout.pages {
                    guard case .content(let blocks) = page, let last = blocks.last else { continue }
                    XCTAssertNotEqual(last, .feelingsHeader)
                    XCTAssertNotEqual(last, .feelingPatternsHeader)
                }
            }
        }
    }

    /// A table that fits on a page isn't split: with two sections leaving too little room for all four rows, the
    /// header and rows start the next page together. One too long for a page still splits.
    func testHowYouFeltKeepsAShortTableTogether() {
        let layout = ReportLayout(report: fixture(sections: 2, notes: 0, feelings: 4), paper: .a4)
        XCTAssertEqual(Array(layout.pages.dropFirst()), [
            .content([.section(0), .section(1)]),
            .content([.feelingsHeader, .feelings(0..<4)]),
        ])
        let long = ReportLayout(report: fixture(sections: 0, notes: 0, feelings: 40), paper: .a4)
        XCTAssertEqual(long.pages.count, 3, "the cover, then 40 rows over two pages")
    }

    /// The patterns stay with How you felt's rows: when the two don't fit together under the sections, the whole
    /// section starts the next page (the patterns alone on a page had no title above them).
    func testHowYouFeltsPatternsStayWithItsRows() {
        // Two sections leave 158 pt: room for the header and three rows (140), not for the patterns too.
        let layout = ReportLayout(report: fixture(sections: 2, notes: 0, feelings: 3, patterns: 1), paper: .a4)
        XCTAssertEqual(Array(layout.pages.dropFirst()), [
            .content([.section(0), .section(1)]),
            .content([.feelingsHeader, .feelings(0..<3), .feelingPatternsHeader, .feelingPatterns(0..<1)]),
        ])
    }

    func testTheCaptionNamesTheScalesInUse() {
        func caption(_ kinds: [FeelingKind]) -> String {
            var report = fixture(sections: 0, notes: 0)
            report.feelings = kinds.map {
                DoctorReport.Feeling(title: "Q", kind: $0, average: 1, yesDays: 1, answeredDays: 1, lowWord: "Low",
                                     highWord: "High")
            }
            return ReportText(report: report).feelingsCaption
        }
        XCTAssertEqual(caption([.scale, .scale]), "Self-reported: a daily answer to each question in nutrx, on a 1 to 5 scale.")
        XCTAssertEqual(caption([.yesNo]), "Self-reported: a daily answer to each question in nutrx, yes or no.")
        XCTAssertEqual(caption([.scale, .yesNo]),
                       "Self-reported: a daily answer to each question in nutrx, on a 1 to 5 scale or yes or no.")
    }

    /// A section too long for one page (many findings) splits, and its patterns start right under its rows rather
    /// than alone on a fresh page without "How you felt" above them.
    func testALongHowYouFeltSplitsWithItsPatternsUnderItsRows() {
        let report = fixture(sections: 1, notes: 0, feelings: 3, patterns: 18)
        let layout = ReportLayout(report: report, paper: .a4)
        guard case .content(let first) = layout.pages[1] else { return XCTFail("expected a content page") }
        XCTAssertEqual(Array(first.prefix(4)), [.section(0), .feelingsHeader, .feelings(0..<3), .feelingPatternsHeader])
        let patterns = layout.pages.flatMap { page -> [Int] in
            guard case .content(let blocks) = page else { return [] }
            return blocks.flatMap { block -> [Int] in
                if case .feelingPatterns(let range) = block { return Array(range) }
                return []
            }
        }
        XCTAssertEqual(patterns, Array(0..<18))
    }

    /// Without answers there's no How you felt at all.
    func testNoFeelingsNoBlocks() {
        let layout = ReportLayout(report: fixture(sections: 1, notes: 0), paper: .a4)
        XCTAssertEqual(layout.pages, [.cover(summaryRows: 0..<1), .content([.section(0)])])
    }

    // MARK: - How you felt (#133)

    private func question(_ title: String, kind: FeelingKind = .scale, preset: FeelingPreset? = nil,
                          answers: [Int: Int]) -> FeelingTrends.Question {
        FeelingTrends.Question(title: title, kind: kind, preset: preset, aboutNightBefore: false,
                               answers: Dictionary(uniqueKeysWithValues: answers.map { (day(10, $0.key), $0.value) }))
    }

    func testHowYouFeltSumsThePeriodsAnswers() throws {
        // 1–10 October. Energy every day (and 30 September, outside); Mood on two days; a yes / no on 7; one
        // question answered only outside the period.
        var energyAnswers = Dictionary(uniqueKeysWithValues: (1...10).map { (day(10, $0), $0 <= 5 ? 4 : 3) })
        energyAnswers[day(9, 30)] = 1
        let energy = FeelingTrends.Question(title: "Energy", kind: .scale, preset: .energy, aboutNightBefore: false,
                                            answers: energyAnswers)
        let mood = question("Mood", preset: .mood, answers: [2: 5, 3: 4])
        let skin = question("Skin", kind: .yesNo, answers: [1: 1, 2: 0, 3: 1, 4: 0, 5: 1, 6: 0, 7: 0])
        let focus = question("Focus", preset: .focus, answers: [20: 3])
        let feelings = DoctorReport.feelings([energy, mood, skin, focus], start: day(10, 1), end: day(10, 10))

        XCTAssertEqual(feelings.map(\.title), ["Energy", "Mood", "Skin"], "in order, without the unanswered one")
        XCTAssertEqual(feelings[0].average, 3.5)
        XCTAssertEqual(feelings[0].answeredDays, 10, "30 September is outside the period")
        XCTAssertEqual(feelings[1].average, 4.5)
        XCTAssertEqual(feelings[2].yesDays, 3)
        XCTAssertEqual(feelings[2].answeredDays, 7)

        let text = ReportText(report: report(), calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text.feelingValue(feelings[0]), "3.5 on average")
        XCTAssertEqual(text.feelingScale(feelings[0]), "1 Low – 5 High")
        XCTAssertEqual(text.feelingScale(feelings[1]), "1 Poor – 5 Great", "Mood's own end words")
        XCTAssertEqual(text.feelingValue(feelings[2]), "Yes on 3 days")
        XCTAssertEqual(text.feelingScale(feelings[2]), "Yes or no")
        XCTAssertEqual(text.feelingAnswered(feelings[2]), "7 of 10 days answered")
        let once = DoctorReport.feelings([question("Skin", kind: .yesNo, answers: [1: 1, 2: 0])],
                                         start: day(10, 1), end: day(10, 10))
        XCTAssertEqual(text.feelingValue(try XCTUnwrap(once.first)), "Yes on 1 day")
        XCTAssertEqual(text.feelingPatternsHeader,
                       "With nutrients · the 28 days to Oct 10 · patterns in the answers, not causes")
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
            let used = blocks.reduce(CGFloat(0)) { $0 + ReportLayout.height(of: $1, in: report, paper: .a4) }
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

    // MARK: - Dose plans (#135)

    func testAPlanGivesEachDayItsGoalAndTheSectionItsSteps() throws {
        // Vitamin D at 2,000 IU from 1 to 5 October, then 4,000 IU; 2,000 logged every day.
        var list = nutrients
        list[0].dosePlan = NutrientDosePlan().creating(
            steps: [.init(goal: NutrientGoal(target: 2000), days: 5), .init(goal: NutrientGoal(target: 4000), days: 5)],
            end: .keep, start: day(10, 1), base: NutrientGoal(target: 4000), today: day(10, 1), calendar: calendar)
        var totals: [Date: [UUID: Double]] = [:]
        for d in 1...10 { totals[day(10, d)] = [vitaminD: 2000, caffeine: 200] }
        let log = HistoryLog(nutrients: list, totals: totals, today: day(10, 15), calendar: calendar)
        let report = DoctorReport.build(log: log, names: names, units: units, start: day(10, 1), end: day(10, 10))

        let d = try XCTUnwrap(report.sections.first { $0.id == vitaminD })
        XCTAssertEqual(d.metDays, 5, "2,000 IU met the first step, not the second")
        XCTAssertEqual(d.goalRuns, [DoctorReport.GoalRun(goal: NutrientGoal(target: 2000), first: 0, last: 4),
                                    DoctorReport.GoalRun(goal: NutrientGoal(target: 4000), first: 5, last: 9)])
        XCTAssertEqual(d.target, 4000, "the goal on the period's last day")
        let text = ReportText(report: report, calendar: calendar, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(text.goal(d), "At least 2,000 → 4,000 IU")
        XCTAssertEqual(text.goalLine(d), "Goal: at least 2,000 → 4,000 IU")
        XCTAssertEqual(text.planLine(d), "Dose plan: 2,000 IU until Oct 5, then 4,000 IU")
        XCTAssertEqual(ReportLayout.blockHeight(d), ReportLayout.sectionHeight + ReportLayout.planLineHeight)

        let steady = try XCTUnwrap(report.sections.first { $0.id == caffeine })
        XCTAssertNil(text.planLine(steady))
        XCTAssertEqual(text.goal(steady), "At most 400 mg")
        XCTAssertEqual(ReportLayout.blockHeight(steady), ReportLayout.sectionHeight)
    }

    func testManyStepsNameTheFirstAndTheLastAndARangeBothEnds() {
        func days(_ goals: [NutrientGoal]) -> [DoctorReport.Day] {
            goals.enumerated().map { DoctorReport.Day(date: day(10, $0.offset + 1), total: nil, isMet: false, goal: $0.element) }
        }
        func section(_ goalType: GoalType, unit: String, _ goals: [NutrientGoal]) -> DoctorReport.Section {
            DoctorReport.Section(id: UUID(), name: "N", unit: unit, goalType: goalType, target: goals.last!.target,
                                 upperBound: goals.last!.upperBound, days: days(goals), countedDays: 0, metDays: 0,
                                 daysLogged: 0, average: nil)
        }
        let text = ReportText(report: report(), calendar: calendar, locale: Locale(identifier: "en_US"))
        let taper = section(.maximum, unit: "mg", [400, 300, 200, 100].map { NutrientGoal(target: $0) })
        XCTAssertEqual(text.goal(taper), "At most 400 → 100 mg")
        XCTAssertEqual(text.planLine(taper),
                       "Dose plan: 400 mg until Oct 1, then 300 mg until Oct 2, then 200 mg until Oct 3, then 100 mg")
        let three = section(.maximum, unit: "mg", [400, 300, 200].map { NutrientGoal(target: $0) })
        XCTAssertEqual(text.goal(three), "At most 400 → 300 → 200 mg")
        let range = section(.range, unit: "g", [NutrientGoal(target: 120, upperBound: 160),
                                                NutrientGoal(target: 140, upperBound: 180)])
        XCTAssertEqual(text.goal(range), "Between 120–160 → 140–180 g")
        XCTAssertEqual(text.planLine(range), "Dose plan: 120–160 g until Oct 1, then 140–180 g")
    }
}
