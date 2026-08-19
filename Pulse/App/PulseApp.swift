import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var services = AppServices()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(services)
                .environment(appState)
        }
        .modelContainer(for: [Workout.self, SetEntry.self, Exercise.self, Goal.self, GymLocation.self])
    }
}
