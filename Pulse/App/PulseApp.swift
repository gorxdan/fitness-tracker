import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Workout.self, SetEntry.self, Exercise.self, Goal.self, GymLocation.self])
    }
}
