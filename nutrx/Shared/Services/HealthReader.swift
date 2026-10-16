import Foundation
import HealthKit
import os

/// Reads sleep, workouts and active energy from Apple Health for health trends (nutrx Pro, phase 7): read only, live,
/// into memory. Nothing read is stored in SwiftData, UserDefaults or iCloud, or shown in widgets.
@MainActor
enum HealthReader {
    /// Where the days come from: HealthKit, or (Debug) a demo set for checking the screens in the simulator.
    protocol Source {
        func days(from start: Date, to end: Date, calendar: Calendar) async -> [Date: HealthDay]
    }

    static let logger = Logger(subsystem: "nutrx-labs.nutrx", category: "HealthReader")

    /// The user turned trends with Apple Health on in nutrx (this device; HealthKit itself never says whether read
    /// access was granted).
    static let connectedKey = "nutrx.healthConnected"

    static var isConnected: Bool { UserDefaults.standard.bool(forKey: connectedKey) }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static let readTypes: Set<HKObjectType> = [
        HKCategoryType(.sleepAnalysis), HKWorkoutType.workoutType(), HKQuantityType(.activeEnergyBurned),
    ]

    private static let store = HKHealthStore()

    /// Shows the system permission sheet (only the first time; afterwards changes are made in the Health app) and
    /// marks trends as connected. Returns false when HealthKit isn't available or the request failed.
    static func connect() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            UserDefaults.standard.set(true, forKey: connectedKey)
            return true
        } catch {
            logger.error("Health authorization failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    static func disconnect() {
        UserDefaults.standard.set(false, forKey: connectedKey)
    }

    static var source: Source {
        #if DEBUG
        // Checking the card in the simulator, whose Health store is empty: `simctl spawn <UDID> defaults write
        // nutrx-labs.nutrx nutrx.debug.healthDemo -bool YES` (Debug builds only).
        if UserDefaults.standard.bool(forKey: "nutrx.debug.healthDemo") { return DemoHealthSource() }
        #endif
        return HealthKitSource(store: store)
    }

    /// Health days for the last `days` completed days and today, by start of day; empty when not connected.
    static func recentDays(_ days: Int, now: Date = .now, calendar: Calendar = .current) async -> [Date: HealthDay] {
        guard isConnected else { return [:] }
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -days, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return await source.days(from: start, to: end, calendar: calendar)
    }

    /// What Settings shows per type: whether any of it was found in the last four weeks.
    static func typesWithData(now: Date = .now, calendar: Calendar = .current) async -> (sleep: Bool, workouts: Bool, energy: Bool) {
        let days = await recentDays(HealthTrends.windowDays, now: now, calendar: calendar).values
        return (days.contains { $0.sleepMinutes != nil }, days.contains(where: \.workedOut),
                days.contains { $0.activeEnergy != nil })
    }
}

// MARK: - HealthKit

private struct HealthKitSource: HealthReader.Source {
    let store: HKHealthStore

    func days(from start: Date, to end: Date, calendar: Calendar) async -> [Date: HealthDay] {
        async let sleep = sleepMinutes(from: start, to: end, calendar: calendar)
        async let workouts = workoutDays(from: start, to: end, calendar: calendar)
        async let energy = activeEnergy(from: start, to: end, calendar: calendar)
        let (sleepByDay, workoutDays, energyByDay) = await (sleep, workouts, energy)

        var result: [Date: HealthDay] = [:]
        for (day, minutes) in sleepByDay { result[day, default: HealthDay()].sleepMinutes = minutes }
        for day in workoutDays { result[day, default: HealthDay()].workedOut = true }
        for (day, kcal) in energyByDay { result[day, default: HealthDay()].activeEnergy = kcal }
        return result
    }

    /// Minutes asleep per night, credited to the day before the morning it ends (sleep ending before noon belongs to
    /// the previous day's night).
    private func sleepMinutes(from start: Date, to end: Date, calendar: Calendar) async -> [Date: Double] {
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        let predicate = HKQuery.predicateForSamples(withStart: start, end: calendar.date(byAdding: .day, value: 1, to: end))
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
                                                 sortDescriptors: [])
        guard let samples = try? await descriptor.result(for: store) else { return [:] }
        var minutes: [Date: Double] = [:]
        for sample in samples where asleep.contains(sample.value) {
            let night = calendar.startOfDay(for: sample.endDate.addingTimeInterval(-12 * 3600))
            minutes[night, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 60
        }
        return minutes
    }

    private func workoutDays(from start: Date, to end: Date, calendar: Calendar) async -> Set<Date> {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        guard let workouts = try? await descriptor.result(for: store) else { return [] }
        return Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
    }

    private func activeEnergy(from start: Date, to end: Date, calendar: Calendar) async -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.activeEnergyBurned), predicate: predicate),
            options: .cumulativeSum, anchorDate: calendar.startOfDay(for: start), intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var energy: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()), sum > 0 {
                energy[calendar.startOfDay(for: statistics.startDate)] = sum
            }
        }
        return energy
    }
}

#if DEBUG
/// A plausible four weeks for the simulator: workouts on about half the days, shorter nights after some days.
private struct DemoHealthSource: HealthReader.Source {
    func days(from start: Date, to end: Date, calendar: Calendar) async -> [Date: HealthDay] {
        var result: [Date: HealthDay] = [:]
        var day = calendar.startOfDay(for: start)
        var index = 0
        while day < end {
            let workout = index % 7 < 3
            result[day] = HealthDay(sleepMinutes: index % 3 == 0 ? 390 : 440, workedOut: workout,
                                    activeEnergy: workout ? 650 : 280)
            index += 1
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}
#endif
