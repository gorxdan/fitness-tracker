import Foundation
import Observation

/// Owns session-level UI state: the active session sheet and arrival deep links.
@MainActor
@Observable
final class AppState {
    var sessionActive = false
    var sessionPrefillTitle: String?

    func startSession(prefill: String? = nil) {
        sessionPrefillTitle = prefill
        sessionActive = true
    }

    /// Notification tap: "At <gym> — start a workout?"
    func handleArrival(_ gymName: String) {
        startSession(prefill: "\(gymName) Workout")
    }
}
