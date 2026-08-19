import CoreLocation
import UserNotifications

/// Plain value passed to the service so CoreLocation code never touches SwiftData models.
struct GymRegion: Sendable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

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

/// Gym arrival detection: geofences around saved gyms, local notification on entry.
/// With When-In-Use access, monitoring works while the app is in use; background
/// arrival prompts need Always (Settings explains this — see docs/INTEGRATIONS.md).
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// (gym id, gym name) on region entry — the app layer schedules the notification.
    var onArrival: (@Sendable (UUID, String) -> Void)?

    private let manager = CLLocationManager()
    private var gymNames: [String: String] = [:] // region identifier → gym name
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
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
    /// personal use stays well under the limit).
    func monitor(gyms: [GymRegion]) {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        gymNames = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id.uuidString, $0.name) })
        guard manager.authorizationStatus.isPermitted else { return }
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

    /// Fires the "at the gym" notification; the tap is routed by AppDelegate.
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

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        authContinuation?.resume(returning: manager.authorizationStatus)
        authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let name = gymNames[region.identifier],
              let id = UUID(uuidString: region.identifier)
        else { return }
        onArrival?(id, name)
    }
}

extension CLAuthorizationStatus {
    var isPermitted: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
}
