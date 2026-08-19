import SwiftUI
import SwiftData

/// Workout logging session screen. Build phase implements exercise picker, set logging,
/// playlist attachment, and finish flow (notes/feel/pain + HealthKit save).
struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Session logging",
                systemImage: "timer",
                description: Text("Set logging, playlist and workout notes arrive in the build phase.")
            )
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}
