import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: String
    var isCardio: Bool

    init(id: UUID = UUID(), name: String, muscleGroup: MuscleGroup, isCardio: Bool = false) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup.rawValue
        self.isCardio = isCardio
    }
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, legs, shoulders, arms, core, cardio
}

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date?
    var feelRating: Int?
    var painLevel: Int?
    var painLocation: String?
    var notes: String
    var musicProvider: String?
    var musicPlaylistID: String?
    var musicPlaylistName: String?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workout) var sets: [SetEntry]

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        feelRating: Int? = nil,
        painLevel: Int? = nil,
        painLocation: String? = nil,
        notes: String = "",
        musicProvider: MusicProvider? = nil,
        musicPlaylistID: String? = nil,
        musicPlaylistName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.feelRating = feelRating
        self.painLevel = painLevel
        self.painLocation = painLocation
        self.notes = notes
        self.musicProvider = musicProvider?.rawValue
        self.musicPlaylistID = musicPlaylistID
        self.musicPlaylistName = musicPlaylistName
        self.sets = []
    }
}

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    var workout: Workout?
    var exercise: Exercise?
    var index: Int
    var reps: Int
    var weightKg: Double
    var rpe: Double?
    var distanceKm: Double?

    init(
        id: UUID = UUID(),
        index: Int,
        reps: Int,
        weightKg: Double,
        rpe: Double? = nil,
        distanceKm: Double? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.index = index
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.distanceKm = distanceKm
        self.exercise = exercise
    }
}

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var kind: String
    var targetValue: Double
    var exercise: Exercise?
    var createdAt: Date

    init(id: UUID = UUID(), kind: GoalKind, targetValue: Double, exercise: Exercise? = nil, createdAt: Date = .now) {
        self.id = id
        self.kind = kind.rawValue
        self.targetValue = targetValue
        self.exercise = exercise
        self.createdAt = createdAt
    }
}

enum GoalKind: String, Codable, CaseIterable {
    case weeklyWorkouts, bodyWeight, oneRepMax
}

extension Workout {
    /// Sum of reps × weight across logged sets (stored kg).
    var volumeKg: Double {
        sets.reduce(0) { $0 + FitnessMath.volume(reps: $1.reps, weightKg: $1.weightKg) }
    }

    /// Flattened to PulseCore records for the pure aggregation functions.
    func records() -> [SetRecord] {
        sets.map { set in
            SetRecord(
                date: startedAt,
                exerciseName: set.exercise?.name ?? "",
                muscleGroup: set.exercise?.muscleGroup ?? "",
                reps: set.reps,
                weightKg: set.weightKg
            )
        }
    }
}
