import Foundation
import Observation

/// Service container injected into the environment; views reach platform
/// features only through these.
@MainActor
@Observable
final class AppServices {
    let health: HealthKitService
    let music: MusicController
    let location: LocationService

    /// True when Apple Music is already authorized (no prompt); used by Settings.
    var appleMusicStatus: Bool {
        music.isAppleMusicAuthorized
    }

    init(
        health: HealthKitService = HealthKitService(),
        music: MusicController = MusicController(),
        location: LocationService = LocationService()
    ) {
        self.health = health
        self.music = music
        self.location = location
    }
}
