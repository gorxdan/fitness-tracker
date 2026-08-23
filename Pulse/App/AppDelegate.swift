import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let gymArrivalTapped = Notification.Name("pulse.gym.arrival.tapped")
}

/// Handles "start a workout?" notification taps. Standalone Sendable class: the
/// UNUserNotificationCenterDelegate requirements are nonisolated, so they can't live
/// on the MainActor-isolated AppDelegate.
final class ArrivalNotificationDelegate: NSObject, Sendable, UNUserNotificationCenterDelegate {
    static let shared = ArrivalNotificationDelegate()

    private override init() {
        super.init()
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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = ArrivalNotificationDelegate.shared
        return true
    }
}
