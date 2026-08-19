import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let gymArrivalTapped = Notification.Name("pulse.gym.arrival.tapped")
}

/// Handles the "start a workout?" notification tap: routes the gym name into the app
/// and lets the arrival banner show while the app is foregrounded.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix("gym-arrival") ? [.banner, .sound] : []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier.hasPrefix("gym-arrival"),
              let gym = response.notification.request.content.userInfo["gym"] as? String
        else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .gymArrivalTapped, object: gym)
        }
    }
}
