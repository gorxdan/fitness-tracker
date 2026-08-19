import Foundation

/// Goal progress math. Inputs come from SwiftData queries + HealthKit; the math itself is pure.
public struct GoalSnapshot: Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var currentText: String
    public var targetText: String
    /// 0...1, clamped. Progress > 1 means the target is beaten.
    public var progress: Double

    public init(id: String, title: String, currentText: String, targetText: String, progress: Double) {
        self.id = id
        self.title = title
        self.currentText = currentText
        self.targetText = targetText
        self.progress = progress
    }
}

public enum GoalMath {
    public static func weeklyWorkouts(
        goalID: String, target: Int, workoutDates: [Date],
        now: Date = .now, calendar: Calendar = .current
    ) -> GoalSnapshot {
        let done = WorkoutStats.workoutsThisWeek(dates: workoutDates, now: now, calendar: calendar)
        return GoalSnapshot(
            id: goalID,
            title: "Workouts this week",
            currentText: "\(done)",
            targetText: "of \(target)",
            progress: target > 0 ? Double(done) / Double(target) : 0
        )
    }

    /// Body-weight goal: progress is movement from the first recorded weight toward the target.
    public static func bodyWeight(
        goalID: String, targetKg: Double, startKg: Double?, latestKg: Double?
    ) -> GoalSnapshot {
        var progress = 0.0
        var currentText = "—"
        if let latest = latestKg {
            currentText = WeightUnit.kilograms.format(kg: latest)
            if let start = startKg {
                let total = abs(targetKg - start)
                if total > 0 {
                    let moved = abs(targetKg - latest)
                    progress = min(1, max(0, (total - moved) / total))
                } else {
                    progress = 1 // already at target when the goal was set
                }
            }
        }
        return GoalSnapshot(
            id: goalID,
            title: "Body weight",
            currentText: currentText,
            targetText: WeightUnit.kilograms.format(kg: targetKg),
            progress: progress
        )
    }

    public static func oneRepMax(
        goalID: String, targetKg: Double, exerciseName: String, sets: [SetRecord]
    ) -> GoalSnapshot {
        let series = WorkoutStats.oneRepMaxSeries(exerciseName: exerciseName, in: sets)
        let best = series.map(\.value).max()
        return GoalSnapshot(
            id: goalID,
            title: "\(exerciseName) · best e1RM",
            currentText: best.map { WeightUnit.kilograms.format(kg: $0) } ?? "—",
            targetText: WeightUnit.kilograms.format(kg: targetKg),
            progress: best.map { $0 / targetKg } ?? 0
        )
    }
}
