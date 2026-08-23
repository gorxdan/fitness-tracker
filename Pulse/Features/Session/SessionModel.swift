import Foundation
import SwiftData

/// In-progress workout state. Saved to SwiftData only when the summary is confirmed.
@MainActor
@Observable
final class SessionModel {
    struct SetDraft: Identifiable {
        let id = UUID()
        var reps: Int
        var weightKg: Double
        var distanceKm: Double?
        var isDone = false
    }

    struct Slot: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var sets: [SetDraft] = []
    }

    var startedAt = Date()
    var slots: [Slot] = []
    var playlist: PlaylistRef?

    var totalVolumeKg: Double {
        slots.flatMap(\.sets)
            .filter(\.isDone)
            .reduce(0) { $0 + FitnessMath.volume(reps: $1.reps, weightKg: $1.weightKg) }
    }

    var doneSetCount: Int {
        slots.flatMap(\.sets).filter(\.isDone).count
    }

    /// Title derived from the day's muscle groups, e.g. "Chest & Back"; cardio-only → "Cardio".
    var defaultTitle: String {
        var groups: [String] = []
        for slot in slots where !groups.contains(slot.exercise.muscleGroup) {
            groups.append(slot.exercise.muscleGroup)
        }
        if groups.isEmpty { return "Workout" }
        if groups == ["cardio"] { return "Cardio" }
        return groups.map(\.capitalized).joined(separator: " & ")
    }

    func addSlot(for exercise: Exercise) {
        guard !slots.contains(where: { $0.exercise.id == exercise.id }) else { return }
        slots.append(Slot(exercise: exercise))
    }

    /// New set prefilled from the last logged set — the one-tap repeat.
    func addSet(to slotID: UUID) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        let exercise = slots[index].exercise
        let last = slots[index].sets.last
        slots[index].sets.append(
            SetDraft(
                reps: last?.reps ?? (exercise.isCardio ? 20 : 8),
                weightKg: last?.weightKg ?? 0,
                distanceKm: last?.distanceKm ?? (exercise.isCardio ? 3 : nil)
            )
        )
    }

    func toggleDone(_ setID: UUID, in slotID: UUID) {
        guard
            let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
            let setIndex = slots[slotIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        slots[slotIndex].sets[setIndex].isDone.toggle()
    }

    func removeSet(_ setID: UUID, in slotID: UUID) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        slots[index].sets.removeAll { $0.id == setID }
    }

    func removeSlot(_ slotID: UUID) {
        slots.removeAll { $0.id == slotID }
    }

    // Typed field access used by the session view's bindings.

    func setValue(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Int>, _ value: Int
    ) {
        mutateSet(setID, slotID) { $0[keyPath: keyPath] = value }
    }

    func setDouble(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Double>, _ value: Double
    ) {
        mutateSet(setID, slotID) { $0[keyPath: keyPath] = value }
    }

    func setOptional(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Double?>, _ value: Double
    ) {
        mutateSet(setID, slotID) { $0[keyPath: keyPath] = value }
    }

    func setValue(_ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Int>) -> Int {
        slot(slotID)?.sets.first { $0.id == setID }?[keyPath: keyPath] ?? 0
    }

    func setDouble(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Double>
    ) -> Double {
        slot(slotID)?.sets.first { $0.id == setID }?[keyPath: keyPath] ?? 0
    }

    func setOptional(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SetDraft, Double?>
    ) -> Double? {
        slot(slotID)?.sets.first { $0.id == setID }?[keyPath: keyPath]
    }

    private func slot(_ slotID: UUID) -> Slot? {
        slots.first { $0.id == slotID }
    }

    private func mutateSet(_ setID: UUID, _ slotID: UUID, _ mutate: (inout SetDraft) -> Void) {
        guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
              let setIndex = slots[slotIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        mutate(&slots[slotIndex].sets[setIndex])
    }

    var canFinish: Bool {
        slots.contains { !$0.sets.isEmpty }
    }
}
