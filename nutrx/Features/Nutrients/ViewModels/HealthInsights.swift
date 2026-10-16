import Foundation
import SwiftData

/// Where Apple Health insights stand across all nutrients (#102), for the places that tell people to keep logging:
/// the connect confirmation, Today's card, Settings → Apple Health and the weekly recap. The findings themselves live
/// in each nutrient's analytics (`HealthTrendsCard`). Read live from Health, never stored (guideline 5.1.3).
enum HealthInsights {
    enum Status: Equatable {
        /// Health has nothing for the last four weeks.
        case noHealthData
        /// No finding yet: the nutrient closest to one, with its paired days ("9 of 14").
        case gathering(nutrientID: UUID, nutrientName: String, pairedDays: Int)
        /// At least one finding: the first nutrient with one, in My Nutrients' order.
        case ready(nutrientID: UUID, nutrientName: String)
        /// Enough days everywhere, nothing that stands out.
        case noPattern
    }

    struct NutrientState: Equatable {
        let id: UUID
        let name: String
        let state: HealthTrends.State
    }

    /// Pure: a finding anywhere wins; otherwise the nutrient with the most paired days that's still gathering (the
    /// first on a tie); otherwise no pattern, or no Health data when that's all there is. Nil with no nutrients.
    static func status(_ states: [NutrientState]) -> Status? {
        guard !states.isEmpty else { return nil }
        if let ready = states.first(where: { if case .findings = $0.state { true } else { false } }) {
            return .ready(nutrientID: ready.id, nutrientName: ready.name)
        }
        var best: (state: NutrientState, days: Int)?
        for state in states {
            if case .notEnoughData(let days) = state.state, days > (best?.days ?? -1) {
                best = (state, days)
            }
        }
        if let best {
            return .gathering(nutrientID: best.state.id, nutrientName: best.state.name, pairedDays: best.days)
        }
        if states.allSatisfy({ $0.state == .noHealthData }) { return .noHealthData }
        return .noPattern
    }

    /// Today's card (#102): which status shows, and what ✕ and See where remember. Pure, so the view stays thin.
    enum TodayCard {
        /// What a hidden card is remembered as: the gathering card, or the first-insight card.
        enum Hidden: Equatable {
            case gathering, ready
        }

        /// The device's flags for a hidden card. No "health" in them: `HealthPrivacyTests` allows only the Health
        /// switch among keys that mention it, and these are UI flags.
        static let hiddenGatheringKey = "nutrx.hidesInsightsGatheringCard"
        static let hiddenReadyKey = "nutrx.hidesInsightsReadyCard"

        /// The status to show: Pro, gathering or ready, and that card not hidden. Nil otherwise.
        static func visible(_ status: Status?, isPro: Bool, hidden: Set<Hidden>) -> Status? {
            guard isPro, let status else { return nil }
            switch status {
            case .gathering: return hidden.contains(.gathering) ? nil : status
            case .ready: return hidden.contains(.ready) ? nil : status
            case .noHealthData, .noPattern: return nil
            }
        }

        /// ✕ hides the card for its state.
        static func hiddenByDismissing(_ status: Status) -> Hidden? {
            switch status {
            case .gathering: .gathering
            case .ready: .ready
            case .noHealthData, .noPattern: nil
            }
        }

        /// See where: the first-insight card has done its job once opened; the gathering one stays until ✕.
        static func hiddenBySeeing(_ status: Status) -> Hidden? {
            if case .ready = status { .ready } else { nil }
        }

        /// The nutrient whose analytics See where opens.
        static func nutrientID(_ status: Status) -> UUID? {
            switch status {
            case .gathering(let id, _, _), .ready(let id, _): id
            case .noHealthData, .noPattern: nil
            }
        }
    }

    /// Every active nutrient's `HealthTrends.state` over the last four weeks, from the store and Apple Health. Nil
    /// when Health isn't connected (or available) or there's nothing tracked.
    static func load(context: ModelContext, now: Date = .now, calendar: Calendar = .current) async -> Status? {
        guard HealthReader.isAvailable, HealthReader.isConnected else { return nil }
        let nutrients = HistoryViewModel.orderedNutrients(context: context).filter { $0.isRunning(on: now) }
        guard !nutrients.isEmpty else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(HealthTrends.windowDays + 1), to: startOfToday)!
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
        let states = nutrients.map { nutrient in
            NutrientState(id: nutrient.id, name: nutrient.name,
                          state: HealthTrends.state(totals: totals[nutrient.id] ?? [:], loggedDays: loggedDays,
                                                    health: health, goal: AnalyticsGoal(nutrient: nutrient),
                                                    createdAt: nutrient.createdAt, today: now, calendar: calendar))
        }
        return status(states)
    }
}
