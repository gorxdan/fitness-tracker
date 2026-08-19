import Foundation
import HealthKit

/// The only surface views may use for HealthKit access.
protocol HealthReading: AnyObject {
    func requestAuthorization() async -> Bool
    func latestBodyMassKg() async -> Double?
    func heightMeters() async -> Double?
    func heartRateStats(start: Date, end: Date) async -> HeartRateStats?
    func saveWorkout(start: Date, end: Date, activeEnergyKcal: Double) async throws
}

struct HeartRateStats: Equatable {
    var averageBPM: Double
    var peakBPM: Double
}

final class HealthKitService: HealthReading {
    private let store = HKHealthStore()

    static let readTypes: Set<HKObjectType> = {
        let q = HKQuantityType.self
        return Set([
            q(.heartRate),
            q(.restingHeartRate),
            q(.heartRateVariabilitySDNN),
            q(.activeEnergyBurned),
            q(.bodyMass),
            q(.height),
            q(.appleExerciseTime),
        ])
    }()

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

    func latestBodyMassKg() async -> Double? {
        await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
    }

    func heightMeters() async -> Double? {
        await latestQuantity(.height, unit: .meter())
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

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let descriptor = HKSamplePredicate.quantitySample(type: type)
        let query = HKSampleQueryDescriptor(predicates: [descriptor], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]) { _, _ in }
        guard let sample = try? await query.result(on: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func statistics(for type: HKQuantityType, from start: Date, to end: Date) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMaximum]) { _, stats, _ in
                continuation.resume(returning: stats)
            }
            store.execute(query)
        }
    }
}
