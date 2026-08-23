import Foundation
import Testing

@testable import PulseCore

@Test func weeklyVolumeBucketsByWeekAndMuscle() {
    let calendar = Calendar(identifier: .iso8601)
    // Monday and the following Saturday land in different ISO weeks.
    let monday = date(2026, 8, 10, calendar: calendar)
    let saturday = date(2026, 8, 15, calendar: calendar)
    let sets = [
        SetRecord(
            date: monday, exerciseName: "Bench", muscleGroup: "chest", reps: 10, weightKg: 60
        ),
        SetRecord(date: monday, exerciseName: "Row", muscleGroup: "back", reps: 10, weightKg: 50),
        SetRecord(
            date: saturday, exerciseName: "Squat", muscleGroup: "legs", reps: 5, weightKg: 100
        ),
    ]
    let range = DateInterval(start: monday, end: saturday.addingTimeInterval(86_400))
    let points = WorkoutStats.weeklyVolume(sets, in: range, calendar: calendar)

    #expect(points.count == 3)
    let week1Start = calendar.dateInterval(of: .weekOfYear, for: monday)!.start
    let week1 = points.filter { $0.weekStart == week1Start }
    #expect(week1.first { $0.muscleGroup == "chest" }?.volumeKg == 600)
    #expect(week1.first { $0.muscleGroup == "back" }?.volumeKg == 500)
    let week2 = points.filter { $0.weekStart != monday }
    #expect(week2.first { $0.muscleGroup == "legs" }?.volumeKg == 500)
}

@Test func weeklyVolumeRespectsRange() {
    let calendar = Calendar(identifier: .iso8601)
    let inRange = date(2026, 8, 10, calendar: calendar)
    let tooOld = date(2026, 5, 1, calendar: calendar)
    let sets = [
        SetRecord(
            date: inRange, exerciseName: "Bench", muscleGroup: "chest", reps: 10, weightKg: 60
        ),
        SetRecord(
            date: tooOld, exerciseName: "Bench", muscleGroup: "chest", reps: 10, weightKg: 60
        ),
    ]
    let range = DateInterval(
        start: inRange.addingTimeInterval(-86_400 * 3),
        end: inRange.addingTimeInterval(86_400)
    )
    #expect(WorkoutStats.weeklyVolume(sets, in: range, calendar: calendar).count == 1)
}

@Test func oneRepMaxSeriesTakesBestPerDay() {
    let calendar = Calendar(identifier: .iso8601)
    let day1 = date(2026, 8, 10, calendar: calendar)
    let day2 = date(2026, 8, 12, calendar: calendar)
    let sets = [
        SetRecord(date: day1, exerciseName: "Bench", muscleGroup: "chest", reps: 8, weightKg: 80),
        SetRecord(
            date: day1.addingTimeInterval(3_600),
            exerciseName: "Bench", muscleGroup: "chest", reps: 5, weightKg: 85
        ),
        SetRecord(date: day2, exerciseName: "Bench", muscleGroup: "chest", reps: 3, weightKg: 90),
        SetRecord(date: day2, exerciseName: "Squat", muscleGroup: "legs", reps: 5, weightKg: 140),
    ]
    let series = WorkoutStats.oneRepMaxSeries(exerciseName: "Bench", in: sets, calendar: calendar)
    #expect(series.count == 2)
    // Day 1 best: 85 × (1 + 5/30) = 99.17, not 80 × (1 + 8/30) = 101.33?
    // 80×1.2667 = 101.33 — that IS higher.
    #expect(abs(series[0].value - 101.33) < 0.01)
    // Day 2: 90 × 1.1 = 99
    #expect(abs(series[1].value - 99.0) < 0.01)
}

@Test func workoutDaysDeduplicatesSameDay() {
    let calendar = Calendar(identifier: .iso8601)
    let morning = date(2026, 8, 10, calendar: calendar)
    let sets = [
        SetRecord(
            date: morning, exerciseName: "Bench", muscleGroup: "chest", reps: 5, weightKg: 60
        ),
        SetRecord(
            date: morning.addingTimeInterval(7_200),
            exerciseName: "Row", muscleGroup: "back", reps: 5, weightKg: 50
        ),
        SetRecord(
            date: date(2026, 8, 12, calendar: calendar),
            exerciseName: "Squat", muscleGroup: "legs", reps: 5, weightKg: 100
        ),
    ]
    #expect(WorkoutStats.workoutDays(sets, calendar: calendar).count == 2)
}

@Test func streakCountsConsecutiveWeeks() {
    let calendar = Calendar(identifier: .iso8601)
    let now = date(2026, 8, 19, calendar: calendar)  // Wednesday
    // This week (Mon 17), last week (Mon 10), two weeks ago (Mon 3) — streak 3.
    let dates = [
        date(2026, 8, 18, calendar: calendar),
        date(2026, 8, 12, calendar: calendar),
        date(2026, 8, 5, calendar: calendar),
    ]
    #expect(WorkoutStats.weeklyStreak(dates: dates, now: now, calendar: calendar) == 3)

    // Gap week (nothing Mon 10–16) kills the streak even with older data.
    let gapped = [
        date(2026, 8, 18, calendar: calendar),
        date(2026, 8, 5, calendar: calendar),
    ]
    #expect(WorkoutStats.weeklyStreak(dates: gapped, now: now, calendar: calendar) == 1)

    // Nothing this week yet but a workout last week: streak 1 (last week only).
    let lastWeekOnly = [date(2026, 8, 12, calendar: calendar)]
    #expect(WorkoutStats.weeklyStreak(dates: lastWeekOnly, now: now, calendar: calendar) == 1)
}

@Test func workoutsThisWeekCountsOnlyCurrentWeek() {
    let calendar = Calendar(identifier: .iso8601)
    let now = date(2026, 8, 19, calendar: calendar)
    let dates = [
        date(2026, 8, 18, calendar: calendar),
        date(2026, 8, 17, calendar: calendar),
        date(2026, 8, 12, calendar: calendar),  // previous week
    ]
    #expect(WorkoutStats.workoutsThisWeek(dates: dates, now: now, calendar: calendar) == 2)
}

private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}
