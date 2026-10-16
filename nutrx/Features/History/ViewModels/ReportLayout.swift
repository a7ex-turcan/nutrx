import CoreGraphics
import Foundation

/// How the report falls onto pages (nutrx Pro, phase 8): the cover with the summary table, then nutrient sections and
/// the notes packed onto content pages. `ImageRenderer` draws one view per page, so the split is decided here, from
/// fixed block heights in points (pure, `DoctorReportTests`).
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
    static let trendLineHeight: CGFloat = 30
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

    static func contentHeight(_ paper: Paper) -> CGFloat {
        paper.size.height - 2 * margin - headerHeight - footerHeight
    }

    static func blockHeight(_ section: DoctorReport.Section) -> CGFloat {
        sectionHeight + CGFloat(section.trends.count) * trendLineHeight
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

        // Content: sections in order, then the notes, filling each page.
        var blocks: [Block] = []
        var used: CGFloat = 0
        func newPage() {
            if !blocks.isEmpty { pages.append(.content(blocks)) }
            blocks = []
            used = 0
        }
        for (index, section) in report.sections.enumerated() {
            let height = Self.blockHeight(section)
            if used + height > available { newPage() }
            blocks.append(.section(index))
            used += height
        }
        if !report.notes.isEmpty {
            let heights = report.notes.map { Self.noteHeight($0, paper: paper) }
            // The header needs room for the first note below it.
            if used + Self.notesHeaderHeight + heights[0] > available { newPage() }
            blocks.append(.notesHeader)
            used += Self.notesHeaderHeight
            var note = 0
            while note < heights.count {
                var next = note
                var height: CGFloat = 0
                while next < heights.count, used + height + heights[next] <= available {
                    height += heights[next]
                    next += 1
                }
                if next == note {
                    newPage()
                    continue
                }
                blocks.append(.notes(note..<next))
                used += height
                note = next
            }
        }
        newPage()
        self.pages = pages
    }
}
