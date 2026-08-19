import Foundation

/// A strength set flattened to value type for aggregation. Views map SwiftData rows to this.
public struct SetRecord: Sendable, Hashable {
    public var date: Date
    public var exerciseName: String
    public var muscleGroup: String
    public var reps: Int
    public var weightKg: Double

    public init(date: Date, exerciseName: String, muscleGroup: String, reps: Int, weightKg: Double) {
        self.date = date
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.reps = reps
        self.weightKg = weightKg
    }
}

public struct DatedValue: Sendable, Hashable, Identifiable {
    public var date: Date
    public var value: Double

    public var id: Date { date }
    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct VolumePoint: Sendable, Hashable, Identifiable {
    public var weekStart: Date
    public var muscleGroup: String
    public var volumeKg: Double

    public var id: String { "\(weekStart.timeIntervalSince1970)-\(muscleGroup)" }
    public init(weekStart: Date, muscleGroup: String, volumeKg: Double) {
        self.weekStart = weekStart
        self.muscleGroup = muscleGroup
        self.volumeKg = volumeKg
    }
}

public enum StatRange: String, CaseIterable, Sendable {
    case oneMonth, threeMonths, oneYear, all

    public var label: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .oneYear: "1Y"
        case .all: "All"
        }
    }

    public func intervalEnding(now: Date = .now) -> DateInterval {
        switch self {
        case .all: DateInterval(start: .distantPast, end: now)
        case .oneMonth: DateInterval(start: now.addingTimeInterval(-30 * 86_400), end: now)
        case .threeMonths: DateInterval(start: now.addingTimeInterval(-90 * 86_400), end: now)
        case .oneYear: DateInterval(start: now.addingTimeInterval(-365 * 86_400), end: now)
        }
    }
}

public enum WorkoutStats {
    /// Weekly training volume summed per muscle group, aligned to start of week.
    public static func weeklyVolume(
        _ sets: [SetRecord],
        in range: DateInterval,
        calendar: Calendar = .current
    ) -> [VolumePoint] {
        var buckets: [Date: [String: Double]] = [:]
        for set in sets where range.contains(set.date) && set.weightKg > 0 {
            let week = calendar.dateInterval(of: .weekOfYear, for: set.date)?.start ?? set.date
            buckets[week, default: [:]][set.muscleGroup, default: 0] +=
                FitnessMath.volume(reps: set.reps, weightKg: set.weightKg)
        }
        return buckets
            .map { week, groups in
                groups.map { VolumePoint(weekStart: week, muscleGroup: $0.key, volumeKg: $0.value) }
            }
            .flatMap { $0 }
            .sorted { $0.weekStart < $1.weekStart }
    }

    /// Best estimated 1RM per day for one exercise — the per-exercise trend series.
    public static func oneRepMaxSeries(
        exerciseName: String,
        in sets: [SetRecord],
        calendar: Calendar = .current
    ) -> [DatedValue] {
        let matching = sets.filter { $0.exerciseName == exerciseName && $0.weightKg > 0 }
        var best: [Date: Double] = [:]
        for set in matching {
            let day = calendar.startOfDay(for: set.date)
            let e1rm = FitnessMath.oneRepMax(weightKg: set.weightKg, reps: set.reps)
            best[day] = max(best[day] ?? 0, e1rm)
        }
        return best
            .map { DatedValue(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Distinct workout days (a session = one day entry), ascending.
    public static func workoutDays(_ sets: [SetRecord], calendar: Calendar = .current) -> [Date] {
        let days = Set(sets.map { calendar.startOfDay(for: $0.date) })
        return days.sorted()
    }

    /// Workouts logged in the current week.
    public static func workoutsThisWeek(dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return dates.filter { week.contains($0) }.count
    }

    /// Consecutive weeks (ending this week) containing at least one workout.
    /// A gap week ends the streak; this week counts if a workout is already logged.
    public static func weeklyStreak(dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        var streak = 0
        // This week only counts once something is logged; previous weeks must all be non-empty.
        if weekHasWorkout(weekStart: cursor, days: days, calendar: calendar) { streak += 1 }
        while true {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            if weekHasWorkout(weekStart: previous, days: days, calendar: calendar) {
                streak += 1
                cursor = previous
            } else {
                break
            }
        }
        return streak
    }

    private static func weekHasWorkout(weekStart: Date, days: Set<Date>, calendar: Calendar) -> Bool {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { return false }
        return days.contains { week.contains($0) }
    }
}
