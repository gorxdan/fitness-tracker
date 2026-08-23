import Foundation

/// Pure mapping from SwiftData goals + workouts + Health body mass to the
/// goal snapshots rendered by Home and Goals. No cached state — the
/// observable values live on AppServices so loads refresh the views.
enum GoalSupport {
    static func snapshots(
        goals: [Goal],
        workouts: [Workout],
        bodyMassStarts: [UUID: Double],
        bodyMassLatest: Double?
    ) -> [GoalSnapshot] {
        let records = workouts.flatMap { $0.records() }
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
                    startKg: bodyMassStarts[goal.id],
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
}
