import Foundation
import Observation

/// Service container injected into the environment; views reach platform
/// features only through these. Observable, so body-mass loads refresh
/// any view rendering body-weight goals.
@MainActor
@Observable
final class AppServices {
    let health: HealthKitService
    let music: MusicController
    let location: LocationService

    /// Body mass from Health for goal math: latest sample, plus the baseline
    /// recorded at (or just after) each body-weight goal's creation.
    var bodyMassStarts: [UUID: Double] = [:]
    var bodyMassLatest: Double?
    private var bodyMassGoalIDs: Set<UUID> = []

    init(
        health: HealthKitService = HealthKitService(),
        music: MusicController = MusicController(),
        location: LocationService = LocationService()
    ) {
        self.health = health
        self.music = music
        self.location = location
    }

    /// Latest mass refreshes on every call; per-goal baselines load once each,
    /// so a goal created after launch anchors without a relaunch.
    func loadBodyMass(goals: [Goal] = []) async {
        bodyMassLatest = await health.latestBodyMassKg()
        for goal in goals
        where goal.kind == GoalKind.bodyWeight.rawValue && !bodyMassGoalIDs.contains(goal.id) {
            bodyMassGoalIDs.insert(goal.id)
            bodyMassStarts[goal.id] = await health.bodyMassOnOrAfter(goal.createdAt)
        }
    }
}
