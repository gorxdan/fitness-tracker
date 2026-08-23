import Foundation
import Testing

@testable import PulseCore

@Test func weeklyWorkoutGoalProgress() {
    let calendar = Calendar(identifier: .iso8601)
    let now = date(2026, 8, 19, calendar: calendar)
    let dates = [date(2026, 8, 17, calendar: calendar), date(2026, 8, 18, calendar: calendar)]
    let snap = GoalMath.weeklyWorkouts(
        goalID: "g1", target: 4, workoutDates: dates, now: now, calendar: calendar
    )
    #expect(snap.currentText == "2")
    #expect(snap.targetText == "of 4")
    #expect(abs(snap.progress - 0.5) < 0.001)
}

@Test func weeklyWorkoutGoalHandlesZeroTarget() {
    let snap = GoalMath.weeklyWorkouts(goalID: "g1", target: 0, workoutDates: [])
    #expect(snap.progress == 0)
}

@Test func bodyWeightGoalMeasuresMovementTowardTarget() {
    // Start 90, target 80, now 85 → halfway.
    let snap = GoalMath.bodyWeight(goalID: "g2", targetKg: 80, startKg: 90, latestKg: 85)
    #expect(abs(snap.progress - 0.5) < 0.001)
    // Already at target → done.
    let done = GoalMath.bodyWeight(goalID: "g2", targetKg: 80, startKg: 85, latestKg: 80)
    #expect(done.progress == 1)
    // Moving away from target → clamped to 0.
    let wrongWay = GoalMath.bodyWeight(goalID: "g2", targetKg: 80, startKg: 85, latestKg: 90)
    #expect(wrongWay.progress == 0)
    // No data yet → 0 with placeholder.
    let none = GoalMath.bodyWeight(goalID: "g2", targetKg: 80, startKg: nil, latestKg: nil)
    #expect(none.progress == 0)
    #expect(none.currentText == "—")
}

@Test func oneRepMaxGoalUsesBestEstimate() {
    let calendar = Calendar(identifier: .iso8601)
    let sets = [
        SetRecord(
            date: date(2026, 8, 10, calendar: calendar),
            exerciseName: "Bench", muscleGroup: "chest", reps: 5, weightKg: 85
        ),
        SetRecord(
            date: date(2026, 8, 12, calendar: calendar),
            exerciseName: "Bench", muscleGroup: "chest", reps: 3, weightKg: 90
        ),
    ]
    let snap = GoalMath.oneRepMax(goalID: "g3", targetKg: 110, exerciseName: "Bench", sets: sets)
    // Best e1RM = 85 × (1 + 5/30) = 99.17 (beats 90 × (1 + 3/30) = 99.0)
    #expect(snap.currentText == "99.2 kg")
    #expect(abs(snap.progress - 99.1667 / 110) < 0.001)
}

@Test func weightUnitRoundsTrip() {
    #expect(abs(WeightUnit.pounds.toKg(WeightUnit.pounds.fromKg(82.5)) - 82.5) < 0.0001)
    #expect(WeightUnit.kilograms.fromKg(100) == 100)
    #expect(WeightUnit.pounds.format(kg: 82.5) == "181.9 lb")
    #expect(WeightUnit.kilograms.format(kg: 82.5) == "82.5 kg")
}

@Test func statRangeIntervals() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let month = StatRange.oneMonth.intervalEnding(now: now)
    #expect(abs(now.timeIntervalSince(month.start) - 30 * 86_400) < 1)
    #expect(StatRange.all.intervalEnding(now: now).start == .distantPast)
}

private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}
