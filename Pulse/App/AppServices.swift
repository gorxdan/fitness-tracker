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

    /// First/latest body mass from Health; loaded once per run for goal math.
    var bodyMassStart: Double?
    var bodyMassLatest: Double?
    private var bodyMassLoaded = false

    init(
        health: HealthKitService = HealthKitService(),
        music: MusicController = MusicController(),
        location: LocationService = LocationService()
    ) {
        self.health = health
        self.music = music
        self.location = location
    }

    func loadBodyMass() async {
        guard !bodyMassLoaded else { return }
        bodyMassLoaded = true
        bodyMassStart = await health.earliestBodyMassKg()
        bodyMassLatest = await health.latestBodyMassKg()
    }
}
