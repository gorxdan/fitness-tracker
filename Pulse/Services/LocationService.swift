import CoreLocation

/// Gym arrival detection. Build phase implements region monitoring + local notification;
/// see docs/INTEGRATIONS.md for the permission strategy (When In Use → optional Always).
protocol GymArrivalObserving: AnyObject {
    func requestLocationPermission() async -> CLAuthorizationStatus
    func monitor(gyms: [GymLocation])
    var onArrival: ((GymLocation) -> Void)? { get set }
}

final class LocationService: NSObject, GymArrivalObserving, CLLocationManagerDelegate {
    var onArrival: ((GymLocation) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocationPermission() async -> CLAuthorizationStatus {
        // Build phase: async wrapper around requestWhenInUseAuthorization.
        manager.authorizationStatus
    }

    func monitor(gyms: [GymLocation]) {
        // Build phase: register CLCircularRegion per gym (id = gym UUID).
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Build phase: resolve gym by region identifier, fire onArrival.
    }
}
