import SwiftData
import SwiftUI

/// Creates a goal. Weekly workouts = count; body weight and e1RM = kg targets
/// (display converts to the user's unit).
struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms

    @State private var kind: GoalKind = .weeklyWorkouts
    @State private var targetCount = 3
    @State private var targetKg: Double
    @State private var exercise: Exercise?

    /// Default target expressed in the user's display unit (80 kg ≈ 176.4 lb),
    /// not a bare 80 that reads as 80 lb for pound users.
    init() {
        let unit =
            WeightUnit(
                rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? ""
            ) ?? .kilograms
        _targetKg = State(initialValue: unit.fromKg(80))
    }

    private var strengthExercises: [Exercise] {
        exercises.filter { !$0.isCardio }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Goal type", selection: $kind) {
                    Text("Workouts per week").tag(GoalKind.weeklyWorkouts)
                    Text("Body weight").tag(GoalKind.bodyWeight)
                    Text("Exercise strength").tag(GoalKind.oneRepMax)
                }
                .pickerStyle(.inline)
                .onChange(of: kind) {
                    if kind == .oneRepMax, exercise == nil {
                        exercise = strengthExercises.first
                    }
                }

                switch kind {
                case .weeklyWorkouts:
                    Stepper("Target: \(targetCount) workouts", value: $targetCount, in: 1...14)
                case .bodyWeight:
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField(
                            "Target",
                            value: $targetKg,
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        Text(weightUnit.label)
                            .foregroundStyle(.secondary)
                    }
                case .oneRepMax:
                    Picker("Exercise", selection: $exercise) {
                        ForEach(strengthExercises) { exercise in
                            Text(exercise.name).tag(Exercise?.some(exercise))
                        }
                    }
                    HStack {
                        Text("Best e1RM target")
                        Spacer()
                        TextField(
                            "Target",
                            value: $targetKg,
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        Text(weightUnit.label)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let storedKg = weightUnit.toKg(targetKg)
                    let goal = Goal(
                        kind: kind,
                        targetValue: kind == .weeklyWorkouts ? Double(targetCount) : storedKg,
                        exercise: kind == .oneRepMax ? exercise : nil
                    )
                    modelContext.insert(goal)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(kind == .oneRepMax && exercise == nil)
            }
        }
    }
}
