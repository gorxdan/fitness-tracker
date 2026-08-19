import Foundation

/// Seed exercise library, inserted on first launch. Names are the identity for
/// matching historical sets, so treat them as stable.
public enum ExerciseCatalog {
    public struct Entry: Sendable, Hashable {
        public let name: String
        public let group: String
        public let cardio: Bool

        public init(_ name: String, _ group: String, cardio: Bool = false) {
            self.name = name
            self.group = group
            self.cardio = cardio
        }
    }

    public static let entries: [Entry] = [
        // Chest
        Entry("Barbell Bench Press", "chest"),
        Entry("Incline Dumbbell Press", "chest"),
        Entry("Dumbbell Fly", "chest"),
        Entry("Cable Crossover", "chest"),
        Entry("Push-Up", "chest"),
        // Back
        Entry("Deadlift", "back"),
        Entry("Barbell Row", "back"),
        Entry("Lat Pulldown", "back"),
        Entry("Seated Cable Row", "back"),
        Entry("Pull-Up", "back"),
        // Legs
        Entry("Back Squat", "legs"),
        Entry("Front Squat", "legs"),
        Entry("Romanian Deadlift", "legs"),
        Entry("Leg Press", "legs"),
        Entry("Walking Lunge", "legs"),
        Entry("Leg Curl", "legs"),
        Entry("Leg Extension", "legs"),
        Entry("Standing Calf Raise", "legs"),
        // Shoulders
        Entry("Overhead Press", "shoulders"),
        Entry("Seated Dumbbell Press", "shoulders"),
        Entry("Lateral Raise", "shoulders"),
        Entry("Face Pull", "shoulders"),
        Entry("Rear Delt Fly", "shoulders"),
        // Arms
        Entry("Barbell Curl", "arms"),
        Entry("Hammer Curl", "arms"),
        Entry("Triceps Pushdown", "arms"),
        Entry("Skull Crusher", "arms"),
        // Core
        Entry("Plank", "core"),
        Entry("Hanging Leg Raise", "core"),
        Entry("Cable Crunch", "core"),
        Entry("Russian Twist", "core"),
        // Cardio (duration + distance logging)
        Entry("Treadmill Run", "cardio", cardio: true),
        Entry("Stationary Bike", "cardio", cardio: true),
        Entry("Rowing Machine", "cardio", cardio: true),
        Entry("Elliptical", "cardio", cardio: true),
    ]
}
