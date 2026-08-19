import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var sessionActive = false

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.strengthtraining.functional",
                        description: Text("Start your first session to begin tracking progress.")
                    )
                } else {
                    List(workouts) { workout in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.title).font(.headline)
                            Text(workout.startedAt, style: .date).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pulse")
            .toolbar {
                Button("Start Workout") { sessionActive = true }
                    .buttonStyle(.borderedProminent)
            }
            .sheet(isPresented: $sessionActive) {
                WorkoutSessionView()
            }
        }
    }
}
