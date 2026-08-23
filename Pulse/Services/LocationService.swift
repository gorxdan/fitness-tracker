import CoreLocation
import UserNotifications

/// Permission state for UI display — keeps CoreLocation types out of the views.
enum LocationAccess: String {
    case notDetermined
    case whenInUse
    case always
    case denied
}

extension LocationAccess {
    var footerText: String {
        switch self {
        case .notDetermined:
            "Location permission is requested when you save your first gym."
        case .always:
            "Always access active — arrival prompts work even when Pulse is closed."
        case .whenInUse:
            "When-In-Use active. For arrival prompts while the app is closed, allow Always in Settings."
        case .denied:
            "Location access is off; turn it on in Settings to use arrival prompts."
        }
    }
}

/// Plain value passed to the service so CoreLocation code never touches SwiftData models.
struct GymRegion: Sendable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

/// Gym arrival detection: geofences around saved gyms, local notification on entry.
/// MainActor because CLLocationManager is MainActor-isolated in the SDK; the
/// CLLocationManagerDelegate requirements are nonisolated, so their implementations
/// are `nonisolated` shims that hop to the main actor.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var gymNames: [String: String] = [:] // region identifier → gym name
    /// Gyms that should be monitored; armed when permission allows. Cached so a
    /// late permission grant can arm regions saved before it existed.
    private var pendingGyms: [GymRegion] = []
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// UI-facing permission state (see LocationAccess).
    var access: LocationAccess {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse: .whenInUse
        case .authorizedAlways: .always
        default: .denied
        }
    }

    /// Prompts for When-In-Use if undetermined; returns the resulting status.
    func requestWhenInUse() async -> CLAuthorizationStatus {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        return manager.authorizationStatus
    }

    /// One-shot fix, used by "use current location" when saving a gym.
    func currentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Replaces all monitored regions with the given gyms (iOS caps monitored regions;
    /// personal use stays well under the limit). Defers arming until permission exists.
    func monitor(gyms: [GymRegion]) {
        pendingGyms = gyms
        arm(gyms: gyms)
    }

    private func arm(gyms: [GymRegion]) {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        gymNames = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id.uuidString, $0.name) })
        guard access.isPermitted else { return }
        for gym in gyms {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: gym.latitude, longitude: gym.longitude),
                radius: gym.radiusMeters,
                identifier: gym.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    static func requestNotificationAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Fires the "at the gym" notification; the tap is routed by ArrivalNotificationDelegate.
    static func scheduleArrivalNotification(gymID: UUID, gymName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "At \(gymName)"
        content.body = "Start a workout?"
        content.userInfo = ["gym": gymName]
        let request = UNNotificationRequest(
            identifier: "gym-arrival-\(gymID.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Main-actor event handling (called from the nonisolated shims below)

    private func resolveAuth() {
        guard manager.authorizationStatus != .notDetermined else { return }
        authContinuation?.resume(returning: manager.authorizationStatus)
        authContinuation = nil
        // Permission may have arrived after gyms were saved — arm them now.
        if access.isPermitted, !pendingGyms.isEmpty {
            arm(gyms: pendingGyms)
        }
    }

    private func resolveLocation(_ location: CLLocation) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    private func failLocation(_ error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    private func handleArrival(regionID: String) {
        guard let name = gymNames[regionID],
              let id = UUID(uuidString: regionID)
        else { return }
        Task {
            await Self.scheduleArrivalNotification(gymID: id, gymName: name)
        }
    }

    // MARK: - CLLocationManagerDelegate (nonisolated shims)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.resolveAuth() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.resolveLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.failLocation(error) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in self.handleArrival(regionID: identifier) }
    }
}

extension LocationAccess {
    var isPermitted: Bool {
        self == .whenInUse || self == .always
    }
}
