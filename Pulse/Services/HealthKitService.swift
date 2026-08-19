import Foundation
import HealthKit

/// The only surface views may use for HealthKit access. MainActor: services are
/// UI-driven and called from views; HealthKit calls are async internally.
@MainActor
protocol HealthReading: AnyObject {
    func requestAuthorization() async -> Bool
    func isAuthorized() async -> Bool
    func latestBodyMassKg() async -> Double?
    func earliestBodyMassKg() async -> Double?
    func heightMeters() async -> Double?
    func heartRateStats(start: Date, end: Date) async -> HeartRateStats?
    func progressSeries(start: Date, end: Date) async -> ProgressSeries
    func saveWorkout(start: Date, end: Date, activeEnergyKcal: Double) async throws
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
        HKQuantityType(.appleExerciseTime),
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
        await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo), ascending: false)
    }

    func earliestBodyMassKg() async -> Double? {
        await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo), ascending: true)
    }

    func heightMeters() async -> Double? {
        await latestQuantity(.height, unit: .meter(), ascending: false)
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
            let results = try await descriptor.results(for: store)
            var series: [DatedValue] = []
            for try await element in results {
                guard case .statistics(let stats) = element else { continue }
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

    func saveWorkout(start: Date, end: Date, activeEnergyKcal: Double) async throws {
        let workout = HKWorkout(activityType: .traditionalStrengthTraining, start: start, end: end)
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

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, ascending: Bool
    ) async -> Double? {
        let type = HKQuantityType(identifier)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: ascending ? .forward : .reverse)]
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func statistics(for type: HKQuantityType, from start: Date, to end: Date) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, stats, _ in
                continuation.resume(returning: stats)
            }
            store.execute(query)
        }
    }
}
