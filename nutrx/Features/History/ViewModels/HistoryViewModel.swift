import Foundation
import SwiftData

@Observable
final class HistoryViewModel {

    struct DaySummary: Identifiable {
        let id: Date // startOfDay
        let date: Date
        var nutrientTotals: [(nutrient: Nutrient, total: Double)]
    }

    struct IntakeEntry: Identifiable {
        let id = UUID()
        let amount: Double
        let date: Date
        let note: String?
    }

    struct MonthSection: Identifiable {
        let id: Date // first day of the month
        let label: String // e.g. "March, 2026"
        var days: [DaySummary]
    }

    private(set) var days: [DaySummary] = []
    private(set) var monthSections: [MonthSection] = []

    func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<IntakeRecord>(
            sortBy: [SortDescriptor(\IntakeRecord.date, order: .reverse)]
        )
        guard let records = try? context.fetch(descriptor) else { return }

        // Group records by calendar day
        var dayMap: [Date: [(nutrientID: PersistentIdentifier, nutrient: Nutrient, amount: Double)]] = [:]

        for record in records {
            guard let nutrient = record.nutrient else { continue }
            let day = Calendar.current.startOfDay(for: record.date)
            dayMap[day, default: []].append((
                nutrientID: nutrient.persistentModelID,
                nutrient: nutrient,
                amount: record.amount
            ))
        }

        // Exclude today
        let today = Calendar.current.startOfDay(for: .now)

        // Build summaries, most recent first
        days = dayMap
            .filter { $0.key < today }
            .map { (day, entries) in
                // Group by nutrient and sum
                var totals: [PersistentIdentifier: (nutrient: Nutrient, total: Double)] = [:]
                for entry in entries {
                    if totals[entry.nutrientID] != nil {
                        totals[entry.nutrientID]!.total += entry.amount
                    } else {
                        totals[entry.nutrientID] = (nutrient: entry.nutrient, total: entry.amount)
                    }
                }

                let nutrientTotals = totals.values
                    .map { (nutrient: $0.nutrient, total: max(0, $0.total)) }
                    .sorted { $0.nutrient.sortOrder < $1.nutrient.sortOrder }

                return DaySummary(id: day, date: day, nutrientTotals: nutrientTotals)
            }
            .sorted { $0.date > $1.date }

        // Group days into month sections
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM, yyyy"

        var sectionMap: [Date: [DaySummary]] = [:]
        for day in days {
            let components = calendar.dateComponents([.year, .month], from: day.date)
            let monthStart = calendar.date(from: components)!
            sectionMap[monthStart, default: []].append(day)
        }

        monthSections = sectionMap
            .map { (monthStart, days) in
                MonthSection(
                    id: monthStart,
                    label: formatter.string(from: monthStart),
                    days: days.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.id > $1.id }
    }

    func intakeRecords(for nutrient: Nutrient, on day: Date, context: ModelContext) -> [IntakeEntry] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate<IntakeRecord> { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\IntakeRecord.date)]
        )
        guard let records = try? context.fetch(descriptor) else { return [] }

        return records
            .filter { $0.nutrient?.persistentModelID == nutrient.persistentModelID }
            .map { IntakeEntry(amount: $0.amount, date: $0.date, note: $0.note) }
    }
}
