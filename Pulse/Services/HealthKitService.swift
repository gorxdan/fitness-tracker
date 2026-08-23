import Foundation
import HealthKit

/// The only surface views may use for HealthKit access. MainActor: services are
/// UI-driven and called from views; HealthKit calls are async internally.
@MainActor
protocol HealthReading: AnyObject {
    func requestAuthorization() async -> Bool
    func isAuthorized() async -> Bool
    func latestBodyMassKg() async -> Double?
    /// Baseline for body-weight goals: first mass at/after goal creation.
    func bodyMassOnOrAfter(_ date: Date) async -> Double?
    func heightMeters() async -> Double?
    func heartRateStats(start: Date, end: Date) async -> HeartRateStats?
    func progressSeries(start: Date, end: Date) async -> ProgressSeries
    func saveWorkout(
        start: Date, end: Date, activeEnergyKcal: Double,
        activityType: HKWorkoutActivityType
    ) async throws
}

struct HeartRateStats: Equatable {
    var averageBPM: Double
    var peakBPM: Double
}

/// Weekly-average trend series used by the Progress tab.
struct ProgressSeries: Sendable {
    var weightKg: [DatedValue]
    var restingHeartRate: [DatedValue]
    var heartRateVariability: [DatedValue]
}

@MainActor
final class HealthKitService: HealthReading {
    private let store = HKHealthStore()

    static let readTypes: Set<HKObjectType> = Set([
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.bodyMass),
        HKQuantityType(.height),
    ])

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: Self.readTypes)
            return true
        } catch {
            return false
        }
    }

    /// True once the user has granted the write side (workouts/energy).
    func isAuthorized() async -> Bool {
        store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func latestBodyMassKg() async -> Double? {
        await quantity(.bodyMass, unit: .gramUnit(with: .kilo), onOrAfter: nil, ascending: false)
    }

    /// Weight-goal baseline anchored at goal creation, not "earliest sample ever".
    func bodyMassOnOrAfter(_ date: Date) async -> Double? {
        await quantity(.bodyMass, unit: .gramUnit(with: .kilo), onOrAfter: date, ascending: true)
    }

    func heightMeters() async -> Double? {
        await quantity(.height, unit: .meter(), onOrAfter: nil, ascending: false)
    }

    func heartRateStats(start: Date, end: Date) async -> HeartRateStats? {
        let type = HKQuantityType(.heartRate)
        guard let sample = await statistics(for: type, from: start, to: end) else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard
            let avg = sample.averageQuantity()?.doubleValue(for: unit),
            let peak = sample.maximumQuantity()?.doubleValue(for: unit)
        else { return nil }
        return HeartRateStats(averageBPM: avg, peakBPM: peak)
    }

    /// Weekly average of a quantity type over a range — the trend series for Progress.
    /// The modern async collection API yields HKStatistics as an AsyncSequence.
    private func weeklyAverages(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date
    ) async -> [DatedValue] {
        let dateRange = HKQuery.predicateForSamples(withStart: start, end: end)
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier), predicate: dateRange
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: .discreteAverage,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: DateComponents(weekOfYear: 1)
        )
        do {
            // result(for:) returns the whole collection (non-streaming); enumerate it.
            let collection = try await descriptor.result(for: store)
            var series: [DatedValue] = []
            collection.enumerateStatistics(from: start, to: end) { stats, _ in
                if let avg = stats.averageQuantity()?.doubleValue(for: unit) {
                    series.append(DatedValue(date: stats.startDate, value: avg))
                }
            }
            return series
        } catch {
            return []
        }
    }

    /// All Progress-tab series in one call; unit construction stays in the service.
    func progressSeries(start: Date, end: Date) async -> ProgressSeries {
        async let weight = weeklyAverages(
            .bodyMass, unit: .gramUnit(with: .kilo), start: start, end: end
        )
        async let resting = weeklyAverages(
            .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()),
            start: start, end: end
        )
        async let hrv = weeklyAverages(
            .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli),
            start: start, end: end
        )
        return await ProgressSeries(
            weightKg: weight, restingHeartRate: resting, heartRateVariability: hrv
        )
    }

    func saveWorkout(
        start: Date, end: Date, activeEnergyKcal: Double,
        activityType: HKWorkoutActivityType = .traditionalStrengthTraining
    ) async throws {
        let workout = HKWorkout(activityType: activityType, start: start, end: end)
        try await store.save(workout)
        let energy = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyKcal),
            start: start,
            end: end
        )
        try await store.addSamples([energy], to: workout)
    }

    // MARK: - Private

    private func quantity(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
        onOrAfter: Date?, ascending: Bool
    ) async -> Double? {
        let type = HKQuantityType(identifier)
        let range = onOrAfter.map { HKQuery.predicateForSamples(withStart: $0, end: nil) }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: range)],
            sortDescriptors: [SortDescriptor(\.endDate, order: ascending ? .forward : .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func statistics(
        for type: HKQuantityType, from start: Date, to end: Date
    ) async -> HKStatistics? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMax]
        )
        return try? await descriptor.result(for: store)
    }
}
