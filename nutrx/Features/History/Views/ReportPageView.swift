import SwiftUI

/// One printed page of the report for your doctor (docs/pro/design/7-doctor-report: pdf-cover, pdf-page), drawn into
/// the PDF by `ReportPDF` and shown scaled in the create sheet. A printed page doesn't follow Dynamic Type or dark
/// mode: sizes are points on paper, black ink on white, and every block is exactly the height `ReportLayout`
/// paginated it with.
struct ReportPageView: View {
    let report: DoctorReport
    let layout: ReportLayout
    let index: Int
    let generatedOn: Date

    private var text: ReportText { ReportText(report: report) }
    private var size: CGSize { layout.paper.size }
    private var contentWidth: CGFloat { size.width - 2 * ReportLayout.margin }

    var body: some View {
        let page = layout.pages[index]
        VStack(alignment: .leading, spacing: 0) {
            header(isCover: index == 0)
                .frame(height: ReportLayout.headerHeight, alignment: .top)
            content(page)
                .frame(width: contentWidth, height: ReportLayout.contentHeight(layout.paper), alignment: .top)
            footer(isCover: index == 0)
                .frame(height: ReportLayout.footerHeight, alignment: .bottom)
        }
        .padding(ReportLayout.margin)
        .frame(width: size.width, height: size.height)
        .background(Color.white)
        .foregroundStyle(Ink.primary)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Header and footer

    private func header(isCover: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                if isCover {
                    // The app icon's mark on forest, the report's only colour.
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 11)
                        .foregroundStyle(Theme.green)
                        .frame(width: 18, height: 18)
                        .background(Theme.forest, in: RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                    Text("nutrx").font(.system(size: 15, weight: .bold))
                } else {
                    Text("nutrx").font(.system(size: 11, weight: .bold))
                }
                Spacer(minLength: 12)
                Text(isCover ? ReportText.title : "\(ReportText.title) · \(text.dates)")
                    .font(.system(size: isCover ? 11 : 9.5))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
            }
            .frame(height: 24)
            Spacer().frame(height: 8)
            Rectangle()
                .fill(isCover ? Ink.primary : Ink.rule)
                .frame(height: isCover ? 1.5 : 0.75)
        }
    }

    private func footer(isCover: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isCover {
                Text(ReportText.disclaimer)
                    .font(.system(size: 9))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Rectangle().fill(Ink.rule).frame(height: 0.75)
            HStack {
                Text(text.generated(on: generatedOn))
                Spacer()
                Text(ReportText.pageNumber(index + 1, of: layout.pages.count))
            }
            .font(.system(size: 8.5))
            .foregroundStyle(Ink.secondary)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ page: ReportLayout.Page) -> some View {
        switch page {
        case .cover(let rows):
            VStack(alignment: .leading, spacing: 0) {
                coverTop.frame(height: ReportLayout.coverTopHeight, alignment: .top)
                if !rows.isEmpty { summaryTable(rows, continued: false) }
            }
        case .summary(let rows):
            summaryTable(rows, continued: true)
        case .content(let blocks):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .section(let index):
                        let section = report.sections[index]
                        sectionBlock(section)
                            .frame(height: ReportLayout.blockHeight(section), alignment: .top)
                    case .notesHeader:
                        notesHeader
                    case .notes(let range):
                        ForEach(range, id: \.self) { noteRow(report.notes[$0], isLast: $0 == report.notes.count - 1) }
                    }
                }
            }
        }
    }

    // MARK: Cover

    private var coverTop: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 30)
            Text(ReportText.title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
            Spacer().frame(height: 6)
            Text(text.period)
                .font(.system(size: 14))
                .foregroundStyle(Ink.secondary)
            Spacer().frame(height: 22)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 9) {
                if let name = report.name { infoRow("Name", name) }
                infoRow("Nutrients tracked", "\(report.sections.count)")
                infoRow("Days with entries", text.daysWithEntries)
            }
            Spacer().frame(height: 22)
            HStack(spacing: 12) {
                factBox("Overall hit rate", text.percent(report.overallHitRate), "Daily goals met, all nutrients")
                factBox("Longest streak", text.longestStreak, "Every goal met each day")
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(Ink.secondary)
            Text(value).fontWeight(.semibold).lineLimit(1)
        }
        .font(.system(size: 11.5))
    }

    private func factBox(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(Ink.secondary)
            Text(value).font(.system(size: 28, weight: .bold)).tracking(-0.5)
            Text(caption).font(.system(size: 9.5)).foregroundStyle(Ink.secondary)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Ink.primary, lineWidth: 1))
    }

    // MARK: Summary table

    private func summaryTable(_ rows: Range<Int>, continued: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(continued ? "\(ReportText.summaryTitle) (continued)" : ReportText.summaryTitle)
                    .font(.system(size: 15, weight: .bold))
                Spacer().frame(height: 16)
                summaryRow("Nutrient", "Goal per day", "Average", "Hit rate", isHeader: true)
                Spacer().frame(height: 6)
                Rectangle().fill(Ink.primary).frame(height: 0.75)
            }
            .frame(height: ReportLayout.summaryHeaderHeight, alignment: .bottom)
            ForEach(rows, id: \.self) { row in
                let section = report.sections[row]
                summaryRow(section.name, text.goal(section), text.average(section), text.percent(section.hitRate),
                           isHeader: false)
                    .frame(height: ReportLayout.summaryRowHeight - 0.5)
                Rectangle().fill(Ink.rule).frame(height: 0.5)
            }
        }
    }

    private func summaryRow(_ name: String, _ goal: String, _ average: String, _ rate: String,
                            isHeader: Bool) -> some View {
        HStack(spacing: 10) {
            Text(name).fontWeight(.semibold)
                .frame(width: contentWidth * 0.27, alignment: .leading)
            Text(goal).fontWeight(isHeader ? .semibold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(average).fontWeight(isHeader ? .semibold : .regular)
                .frame(width: contentWidth * 0.2, alignment: .trailing)
            Text(rate).fontWeight(isHeader ? .semibold : .regular)
                .frame(width: contentWidth * 0.13, alignment: .trailing)
        }
        .font(.system(size: isHeader ? 10.5 : 11))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    // MARK: Nutrient section

    private func sectionBlock(_ section: DoctorReport.Section) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.name)
                    .font(.system(size: 19, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(text.goalLine(section))
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
            }
            .frame(height: 26)
            Spacer().frame(height: 8)
            HStack(spacing: 9) {
                statBox("Hit rate", text.percent(section.hitRate))
                statBox("Average", text.average(section))
                statBox("Days logged", "\(section.daysLogged)")
            }
            .frame(height: 48)
            Spacer().frame(height: 18)
            ReportBarChart(section: section, labels: text.axisLabels(), width: contentWidth)
            Spacer().frame(height: 4)
            Text(ReportText.chartCaption(section.goalType, hasUpperBound: section.upperBound != nil))
                .font(.system(size: 8.5))
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 12)
            if !section.trends.isEmpty {
                Text(ReportText.healthHeader)
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(height: ReportLayout.trendHeaderHeight, alignment: .bottom)
                ForEach(section.trends, id: \.self) { trend in
                    Text(trend)
                        .font(.system(size: 9.5))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(width: contentWidth, height: ReportLayout.trendLineHeight, alignment: .leading)
                }
            }
        }
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9.5)).foregroundStyle(Ink.secondary)
            Text(value).font(.system(size: 16, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Ink.boxRule, lineWidth: 0.75))
    }

    // MARK: Notes

    private var notesHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.system(size: 19, weight: .bold))
            Rectangle().fill(Ink.rule).frame(height: 0.75)
        }
        .frame(height: ReportLayout.notesHeaderHeight, alignment: .bottom)
    }

    private func noteRow(_ note: DoctorReport.Note, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(text.noteDate(note.date))
                    .foregroundStyle(Ink.secondary)
                    .frame(width: contentWidth * 0.13, alignment: .leading)
                Text(note.nutrientName).fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: contentWidth * 0.2, alignment: .leading)
                Text(note.text)
                    .lineLimit(ReportLayout.noteMaxLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 11))
            .padding(.top, 7)
            .frame(maxHeight: .infinity, alignment: .top)
            if !isLast { Rectangle().fill(Ink.rule).frame(height: 0.5) }
        }
        .frame(height: ReportLayout.noteHeight(note, paper: layout.paper))
    }

    /// Black-and-white ink: it prints and photocopies the same.
    enum Ink {
        static let primary = Color(white: 0.07)
        static let secondary = Color(white: 0.33)
        static let rule = Color(white: 0.72)
        static let boxRule = Color(white: 0.6)
        static let barMet = Color(white: 0.13)
        static let barMissed = Color(white: 0.76)
    }
}

/// A section's daily totals as black-and-white bars (pdf-page): dark bars met the goal, light ones didn't, no bar on
/// a day that doesn't count; a dashed line at the goal (both bounds for a range), date labels below. Drawn with
/// shapes so it stays vector in the PDF.
struct ReportBarChart: View {
    let section: DoctorReport.Section
    let labels: [(index: Int, text: String)]
    let width: CGFloat

    static let plotHeight: CGFloat = 76
    static let labelHeight: CGFloat = 12

    var body: some View {
        let count = max(1, section.days.count)
        let slot = width / CGFloat(count)
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Bars(section: section, met: false, scale: scale).fill(ReportPageView.Ink.barMissed)
                Bars(section: section, met: true, scale: scale).fill(ReportPageView.Ink.barMet)
                ForEach(goalLines, id: \.self) { value in
                    GoalLine(fraction: value / scale)
                        .stroke(ReportPageView.Ink.primary, style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
                }
                Rectangle().fill(ReportPageView.Ink.primary).frame(height: 0.75)
            }
            .frame(width: width, height: Self.plotHeight)
            ZStack(alignment: .topLeading) {
                ForEach(labels, id: \.index) { label in
                    let isLast = label.index == count - 1 && label.index > 0
                    let x = CGFloat(label.index) * slot
                    Text(label.text)
                        .font(.system(size: 8.5))
                        .foregroundStyle(ReportPageView.Ink.secondary)
                        .fixedSize()
                        .frame(width: 80, alignment: label.index == 0 ? .leading : isLast ? .trailing : .center)
                        .offset(x: label.index == 0 ? x : isLast ? width - 80 : x + slot / 2 - 40)
                }
            }
            .frame(width: width, height: Self.labelHeight, alignment: .topLeading)
        }
    }

    /// The value at the top of the plot: the highest day or goal, with a little headroom.
    private var scale: Double {
        let highest = ([section.target, section.upperBound ?? 0] + section.days.compactMap(\.total)).max() ?? 1
        return max(highest * 1.08, 0.0001)
    }

    private var goalLines: [Double] {
        if section.goalType == .range, let upper = section.upperBound { return [section.target, upper] }
        return [section.target]
    }

    private struct Bars: Shape {
        let section: DoctorReport.Section
        let met: Bool
        let scale: Double

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let slot = rect.width / CGFloat(max(1, section.days.count))
            let barWidth = max(0.5, slot * 0.72)
            for (index, day) in section.days.enumerated() {
                guard let total = day.total, day.isMet == met else { continue }
                // A logged day at 0 still shows a sliver, so it reads as logged rather than missing.
                let height = max(1, rect.height * CGFloat(total / scale))
                path.addRect(CGRect(x: rect.minX + CGFloat(index) * slot + (slot - barWidth) / 2,
                                    y: rect.maxY - height, width: barWidth, height: height))
            }
            return path
        }
    }

    private struct GoalLine: Shape {
        let fraction: Double

        func path(in rect: CGRect) -> Path {
            let y = rect.maxY - rect.height * CGFloat(min(1, fraction))
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            return path
        }
    }
}
