import SwiftUI

/// Maps SwiftData objects to the pure goal math in PulseCore.
/// Body-weight goals need Health's first/latest mass — fetched once per app run.
@MainActor
final class GoalSupport {
    private static var bodyMassStart: Double?
    private static var bodyMassLatest: Double?
    private static var loaded = false

    static func snapshots(goals: [Goal], workouts: [Workout], health: HealthReading) -> [GoalSnapshot] {
        let records = workouts.flatMap(\.records)
        let dates = workouts.map(\.startedAt)
        return goals.map { goal in
            switch GoalKind(rawValue: goal.kind) ?? .weeklyWorkouts {
            case .weeklyWorkouts:
                GoalMath.weeklyWorkouts(
                    goalID: goal.id.uuidString,
                    target: Int(goal.targetValue),
                    workoutDates: dates
                )
            case .bodyWeight:
                GoalMath.bodyWeight(
                    goalID: goal.id.uuidString,
                    targetKg: goal.targetValue,
                    startKg: bodyMassStart,
                    latestKg: bodyMassLatest
                )
            case .oneRepMax:
                GoalMath.oneRepMax(
                    goalID: goal.id.uuidString,
                    targetKg: goal.targetValue,
                    exerciseName: goal.exercise?.name ?? "",
                    sets: records
                )
            }
        }
    }

    static func loadBodyMass(from health: HealthReading) async {
        guard !loaded else { return }
        loaded = true
        bodyMassStart = await health.earliestBodyMassKg()
        bodyMassLatest = await health.latestBodyMassKg()
    }
}
