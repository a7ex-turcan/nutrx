import CoreGraphics
import Foundation

/// How the report falls onto pages (nutrx Pro, phase 8): the cover with the summary table, then nutrient sections,
/// How you felt (#133) and the notes packed onto content pages. `ImageRenderer` draws one view per page, so the split
/// is decided here, from fixed block heights in points (pure, `DoctorReportTests`).
struct ReportLayout: Equatable {
    enum Paper: Equatable {
        case a4, letter

        /// US Letter where it's the paper in use (the US, Canada, Mexico, the Philippines and a few others), A4 elsewhere.
        static func forRegion(_ region: String?) -> Paper {
            ["US", "CA", "MX", "PH", "CL", "CO", "VE", "GT", "PR"].contains(region ?? "") ? .letter : .a4
        }

        var size: CGSize { self == .a4 ? CGSize(width: 595, height: 842) : CGSize(width: 612, height: 792) }
    }

    enum Block: Equatable {
        case section(Int)
        /// "How you felt" and its self-reported line.
        case feelingsHeader
        /// Question rows, by index into `report.feelings`.
        case feelings(Range<Int>)
        /// The line above How you feel's patterns.
        case feelingPatternsHeader
        /// Pattern sentences, by index into `report.feelingPatterns`.
        case feelingPatterns(Range<Int>)
        case notesHeader
        /// Note rows, by index into `report.notes`.
        case notes(Range<Int>)
    }

    enum Page: Equatable {
        /// The cover, with these rows of the summary table.
        case cover(summaryRows: Range<Int>)
        /// The summary table continued, for a long list of nutrients.
        case summary(rows: Range<Int>)
        case content([Block])
    }

    let paper: Paper
    let pages: [Page]

    // Heights in points, for the page content between the header and the footer.
    static let margin: CGFloat = 54
    static let headerHeight: CGFloat = 40
    static let footerHeight: CGFloat = 56
    static let coverTopHeight: CGFloat = 330
    static let summaryHeaderHeight: CGFloat = 60
    static let summaryRowHeight: CGFloat = 28
    static let sectionHeight: CGFloat = 240
    /// A section's dose plan line, under its title (#135): up to two lines.
    static let planLineHeight: CGFloat = 28
    /// "With Apple Health · last 28 days" above a section's trend lines.
    static let trendHeaderHeight: CGFloat = 20
    static let trendLineHeight: CGFloat = 30
    static let feelingsHeaderHeight: CGFloat = 62
    static let feelingRowHeight: CGFloat = 26
    static let feelingPatternsHeaderHeight: CGFloat = 30
    static let notesHeaderHeight: CGFloat = 44
    static let noteRowHeight: CGFloat = 28
    /// Each line after the first of a wrapped note; the page view caps a note at `noteMaxLines`.
    static let noteLineHeight: CGFloat = 16
    static let noteMaxLines = 3
    /// About how many characters of a note fit on one line of its column.
    static func noteCharactersPerLine(_ paper: Paper) -> Int { paper == .a4 ? 52 : 54 }

    /// A note's row: one line, plus a line per further `noteCharactersPerLine`, up to `noteMaxLines`.
    static func noteHeight(_ note: DoctorReport.Note, paper: Paper) -> CGFloat {
        let perLine = noteCharactersPerLine(paper)
        let lines = min(noteMaxLines, max(1, (note.text.count + perLine - 1) / perLine))
        return noteRowHeight + CGFloat(lines - 1) * noteLineHeight
    }

    /// A content block's height on the page.
    static func height(of block: Block, in report: DoctorReport, paper: Paper) -> CGFloat {
        switch block {
        case .section(let index): blockHeight(report.sections[index])
        case .feelingsHeader: feelingsHeaderHeight
        case .feelings(let rows): CGFloat(rows.count) * feelingRowHeight
        case .feelingPatternsHeader: feelingPatternsHeaderHeight
        case .feelingPatterns(let lines): CGFloat(lines.count) * trendLineHeight
        case .notesHeader: notesHeaderHeight
        case .notes(let rows): rows.reduce(0) { $0 + noteHeight(report.notes[$1], paper: paper) }
        }
    }

    static func contentHeight(_ paper: Paper) -> CGFloat {
        paper.size.height - 2 * margin - headerHeight - footerHeight
    }

    static func blockHeight(_ section: DoctorReport.Section) -> CGFloat {
        let base = sectionHeight + (section.hasSteps ? planLineHeight : 0)
        guard !section.trends.isEmpty else { return base }
        return base + trendHeaderHeight + CGFloat(section.trends.count) * trendLineHeight
    }

    init(report: DoctorReport, paper: Paper) {
        self.paper = paper
        let available = Self.contentHeight(paper)
        var pages: [Page] = []

        // Cover: as many summary rows as fit under the cover's top; the rest continue on summary pages.
        let rowCount = report.sections.count
        let coverRows = max(0, Int((available - Self.coverTopHeight - Self.summaryHeaderHeight) / Self.summaryRowHeight))
        pages.append(.cover(summaryRows: 0..<min(rowCount, coverRows)))
        var row = min(rowCount, coverRows)
        let rowsPerPage = max(1, Int((available - Self.summaryHeaderHeight) / Self.summaryRowHeight))
        while row < rowCount {
            let next = min(rowCount, row + rowsPerPage)
            pages.append(.summary(rows: row..<next))
            row = next
        }

        // Content: sections in order, then How you felt, then the notes, filling each page.
        var blocks: [Block] = []
        var used: CGFloat = 0
        func newPage() {
            if !blocks.isEmpty { pages.append(.content(blocks)) }
            blocks = []
            used = 0
        }
        /// A header and as many of its rows as fit on each page; the header needs room for the first row below it.
        /// A list that `keepsTogether` starts a new page rather than split, when it would fit on one with
        /// `followedBy`, the height of what has to stay with it.
        func addList(_ header: Block, headerHeight: CGFloat, rowHeights heights: [CGFloat], keepsTogether: Bool = false,
                     followedBy: CGFloat = 0, rows: (Range<Int>) -> Block) {
            guard let first = heights.first else { return }
            let whole = headerHeight + heights.reduce(0, +) + followedBy
            if used + headerHeight + first > available
                || keepsTogether && used + whole > available && whole <= available { newPage() }
            blocks.append(header)
            used += headerHeight
            var row = 0
            while row < heights.count {
                var next = row
                var height: CGFloat = 0
                while next < heights.count, used + height + heights[next] <= available {
                    height += heights[next]
                    next += 1
                }
                if next == row {
                    newPage()
                    continue
                }
                blocks.append(rows(row..<next))
                used += height
                row = next
            }
        }
        for (index, section) in report.sections.enumerated() {
            let height = Self.blockHeight(section)
            if used + height > available { newPage() }
            blocks.append(.section(index))
            used += height
        }
        // How you felt reads as one section: its rows and its patterns start a new page together rather than split,
        // when they fit on one (the patterns alone on a page had no title above them). One too long for a page splits,
        // its patterns starting right under its rows.
        let patterns = report.feelingPatterns.isEmpty ? 0
            : Self.feelingPatternsHeaderHeight + CGFloat(report.feelingPatterns.count) * Self.trendLineHeight
        addList(.feelingsHeader, headerHeight: Self.feelingsHeaderHeight,
                rowHeights: report.feelings.map { _ in Self.feelingRowHeight }, keepsTogether: true,
                followedBy: patterns, rows: Block.feelings)
        addList(.feelingPatternsHeader, headerHeight: Self.feelingPatternsHeaderHeight,
                rowHeights: report.feelingPatterns.map { _ in Self.trendLineHeight }, rows: Block.feelingPatterns)
        addList(.notesHeader, headerHeight: Self.notesHeaderHeight,
                rowHeights: report.notes.map { Self.noteHeight($0, paper: paper) }, rows: Block.notes)
        newPage()
        self.pages = pages
    }
}
