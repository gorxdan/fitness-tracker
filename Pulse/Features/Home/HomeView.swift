import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var goals: [Goal]
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms

    private var workoutDates: [Date] { workouts.map(\.startedAt) }
    private var allRecords: [SetRecord] { workouts.flatMap { $0.records() } }
    private var thisWeekVolume: Double {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
            ?? DateInterval(start: .now, end: .now)
        return FitnessMath.totalVolume(
            allRecords
                .filter { week.contains($0.date) }
                .map { (reps: $0.reps, weightKg: $0.weightKg) }
        )
    }

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
                    workoutList
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                Button("Start Workout") { appState.startSession() }
                    .buttonStyle(.borderedProminent)
            }
            .task { await GoalSupport.loadBodyMass(from: services.health) }
        }
    }

    private var workoutList: some View {
        List {
            Section {
                statRow
            } header: {
                Text("This Week").textCase(nil)
            }

            if !goals.isEmpty {
                Section {
                    ForEach(goalSnapshots.prefix(3)) { snapshot in
                        GoalRow(snapshot: snapshot)
                    }
                    NavigationLink("All goals") { GoalsView() }
                        .font(.subheadline)
                } header: {
                    Text("Goals").textCase(nil)
                }
            }

            Section {
                ForEach(workouts.prefix(10)) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRow(workout: workout, unit: weightUnit)
                    }
                }
            } header: {
                Text("Recent").textCase(nil)
            }
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(WorkoutStats.workoutsThisWeek(dates: workoutDates))",
                label: "workouts",
                icon: "figure.run"
            )
            StatCard(
                value: weightUnit == .kilograms
                    ? "\(Int(thisWeekVolume.rounded()))"
                    : "\(Int(WeightUnit.pounds.fromKg(thisWeekVolume).rounded()))",
                label: "\(weightUnit.label) lifted",
                icon: "scalemass"
            )
            StatCard(
                value: "\(WorkoutStats.weeklyStreak(dates: workoutDates))",
                label: "week streak",
                icon: "flame"
            )
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .listRowBackground(Color.clear)
    }

    private var goalSnapshots: [GoalSnapshot] {
        GoalSupport.snapshots(goals: goals, workouts: workouts, health: services.health)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.teal)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WorkoutRow: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.title).font(.headline)
                Spacer()
                if workout.painLevel ?? 0 > 0 {
                    Image(systemName: "bandage")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Logged pain")
                }
                if workout.feelRating != nil {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Has feel rating")
                }
            }
            HStack(spacing: 8) {
                Text(workout.startedAt, format: .dateTime.month(.abbreviated).day())
                Text("·")
                Text("\(workout.sets.count) sets")
                Text("·")
                Text(unit.format(kg: workout.volumeKg, includeUnit: false) + " " + unit.label)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}
