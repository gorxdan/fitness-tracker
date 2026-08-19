import SwiftUI
import SwiftData

struct GoalsView: View {
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var addingGoal = false

    var body: some View {
        List {
            if goals.isEmpty {
                ContentUnavailableView(
                    "No goals yet",
                    systemImage: "target",
                    description: Text("Set a weekly workout, body-weight, or strength target.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(snapshots) { snapshot in
                    GoalRow(snapshot: snapshot)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Add Goal") { addingGoal = true }
        }
        .sheet(isPresented: $addingGoal) {
            GoalEditorView()
        }
        .task { await GoalSupport.loadBodyMass(from: services.health) }
    }

    private var snapshots: [GoalSnapshot] {
        GoalSupport.snapshots(goals: goals, workouts: workouts, health: services.health)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
        try? modelContext.save()
    }
}

/// Shared by Home's goals section and the Goals screen.
struct GoalRow: View {
    let snapshot: GoalSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snapshot.title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(snapshot.currentText) \(snapshot.targetText)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(snapshot.progress, 1))
                .tint(snapshot.progress >= 1 ? .teal : .accentColor)
        }
        .padding(.vertical, 2)
    }
}
