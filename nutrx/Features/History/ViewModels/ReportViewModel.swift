import Foundation
import SwiftData

/// The create sheet's state (docs/pro/design/7-doctor-report: create): the period, which nutrients, and whether the
/// name, notes and Apple Health trends go in; rebuilds the report and its pages whenever one changes.
@Observable
final class ReportViewModel {
    enum Period: Hashable, CaseIterable {
        case days30, days90, custom

        var title: String {
            switch self {
            case .days30: "30 days"
            case .days90: "90 days"
            case .custom: "Custom"
            }
        }
    }

    struct Candidate: Identifiable, Equatable {
        let id: UUID
        let name: String
        /// Logged at least once in the period. One that wasn't starts out of the report: a page of "0 days logged"
        /// would read as a goal never met rather than something not taken.
        let hasEntries: Bool
    }

    var period: Period = .days90 { didSet { rebuild() } }
    var customStart: Date = .now { didSet { rebuild() } }
    var customEnd: Date = .now { didSet { rebuild() } }
    /// Nutrients taken out, and never-logged ones put in, by the user; anything else follows `Candidate.hasEntries`,
    /// so a nutrient that starts counting in a new period gets its default.
    private var excludedIDs: Set<UUID> = [] { didSet { rebuild() } }
    private var addedIDs: Set<UUID> = [] { didSet { rebuild() } }
    var includesName = true { didSet { rebuild() } }
    var includesNotes = true { didSet { rebuild() } }
    var includesHealth = false { didSet { rebuild() } }

    private(set) var report: DoctorReport?
    private(set) var layout: ReportLayout?
    /// The nutrients that count in the period, in display order.
    private(set) var candidates: [Candidate] = []
    private(set) var personName: String?
    /// The first day with anything logged, and yesterday: the custom period's bounds.
    private(set) var earliestDay: Date = .now
    private(set) var latestDay: Date = .now

    private var log: HistoryLog?
    private var names: [UUID: String] = [:]
    private var units: [UUID: String] = [:]
    private var notes: [DoctorReport.NoteEntry] = []
    private var trends: [UUID: [String]] = [:]
    private var now: Date = .now
    private let paper = ReportLayout.Paper.forRegion(Locale.current.region?.identifier)

    var selectedCount: Int { candidates.filter(isIncluded).count }

    func isIncluded(_ candidate: Candidate) -> Bool {
        candidate.hasEntries ? !excludedIDs.contains(candidate.id) : addedIDs.contains(candidate.id)
    }

    func toggle(_ candidate: Candidate) {
        let included = isIncluded(candidate)
        if candidate.hasEntries {
            if included { excludedIDs.insert(candidate.id) } else { excludedIDs.remove(candidate.id) }
        } else {
            if included { addedIDs.remove(candidate.id) } else { addedIDs.insert(candidate.id) }
        }
    }

    /// "All 6", or "4 of 6".
    var nutrientsValue: String {
        selectedCount == candidates.count ? "All \(candidates.count)" : "\(selectedCount) of \(candidates.count)"
    }

    var canCreate: Bool { (report?.daysWithEntries ?? 0) > 0 && !(report?.sections.isEmpty ?? true) }

    func load(context: ModelContext, now: Date = .now) {
        self.now = now
        let calendar = Calendar.current
        let (log, nutrients) = HistoryViewModel.loadLog(context: context, now: now)
        self.log = log
        names = Dictionary(nutrients.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        units = Dictionary(nutrients.map { ($0.id, $0.unit) }, uniquingKeysWith: { first, _ in first })
        let records = (try? context.fetch(FetchDescriptor<IntakeRecord>())) ?? []
        notes = records.compactMap { record in
            guard let nutrient = record.nutrient,
                  let note = record.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
            return DoctorReport.NoteEntry(date: record.date, nutrientID: nutrient.id, text: note)
        }
        let name = ((try? context.fetch(FetchDescriptor<UserProfile>()))?.first?.name ?? "")
            .trimmingCharacters(in: .whitespaces)
        personName = name.isEmpty ? nil : name

        latestDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        earliestDay = min(log.firstDay ?? latestDay, latestDay)
        let last90 = DoctorReport.lastDays(90, today: now, calendar: calendar)
        customStart = max(last90.start, earliestDay)
        customEnd = latestDay
        rebuild()
    }

    /// Apple Health trend lines per nutrient over the last four weeks, read live (never stored) when the toggle is on.
    func loadHealthTrends(context: ModelContext) async {
        guard let log else { return }
        let calendar = Calendar.current
        let days = HealthTrends.windowDays + 1
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        let records = (try? context.fetch(FetchDescriptor<IntakeRecord>(predicate: #Predicate { $0.date >= start }))) ?? []
        var totals: [UUID: [Date: Double]] = [:]
        var loggedDays: Set<Date> = []
        for record in records {
            guard let nutrient = record.nutrient else { continue }
            let day = calendar.startOfDay(for: record.date)
            totals[nutrient.id, default: [:]][day, default: 0] += record.amount
            loggedDays.insert(day)
        }
        let health = await HealthReader.recentDays(HealthTrends.windowDays, now: now, calendar: calendar)
        var result: [UUID: [String]] = [:]
        for nutrient in log.nutrients {
            let goal = AnalyticsGoal(goalType: nutrient.goalType, target: nutrient.target, upperBound: nutrient.upperBound)
            let state = HealthTrends.state(totals: totals[nutrient.id] ?? [:], loggedDays: loggedDays, health: health,
                                           goal: goal, createdAt: nutrient.createdAt, today: now, calendar: calendar)
            guard case .findings(let findings) = state else { continue }
            let words = HealthText(nutrientName: names[nutrient.id] ?? "", unit: units[nutrient.id] ?? "", goal: goal)
            result[nutrient.id] = findings.map(words.sentence)
        }
        trends = result
        rebuild()
    }

    private func rebuild() {
        guard let log else { return }
        let calendar = log.calendar
        let range: (start: Date, end: Date) = switch period {
        case .days30: DoctorReport.lastDays(30, today: now, calendar: calendar)
        case .days90: DoctorReport.lastDays(90, today: now, calendar: calendar)
        case .custom: (min(customStart, customEnd), customEnd)
        }
        // Every nutrient that counts in the period, then the ones left in.
        let all = DoctorReport.build(log: log, names: names, units: units, start: range.start, end: range.end)
        let newCandidates = all.sections.map { Candidate(id: $0.id, name: $0.name, hasEntries: $0.daysLogged > 0) }
        if newCandidates != candidates { candidates = newCandidates }
        let included = newCandidates.filter(isIncluded).map(\.id)
        var report = DoctorReport.build(log: log, names: names, units: units, start: range.start, end: range.end,
                                        nutrientIDs: included, personName: includesName ? personName : nil,
                                        notes: includesNotes ? notes : [])
        if includesHealth {
            report = report.withTrends(trends)
        }
        self.report = report
        layout = ReportLayout(report: report, paper: paper)
    }
}

extension DoctorReport {
    /// The same report with these Apple Health trend lines on its sections.
    func withTrends(_ trends: [UUID: [String]]) -> DoctorReport {
        DoctorReport(start: start, end: end, name: name,
                     sections: sections.map { section in
                         var section = section
                         section.trends = trends[section.id] ?? []
                         return section
                     },
                     notes: notes, daysWithEntries: daysWithEntries, overallHitRate: overallHitRate,
                     longestStreak: longestStreak, days: days)
    }
}
