import SwiftUI
import SwiftData

/// Picks an exercise from the seeded library. Custom exercises are a documented
/// later feature — scope discipline keeps this a pure picker.
struct ExercisePickerView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var group: MuscleGroup?

    let onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            (group == nil || exercise.muscleGroup == group!.rawValue)
                && (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Muscle group", selection: $group) {
                    Text("All").tag(MuscleGroup?.none)
                    ForEach(MuscleGroup.allCases.filter { $0 != .cardio }, id: \.self) { group in
                        Text(group.rawValue.capitalized).tag(MuscleGroup?.some(group))
                    }
                    Text("Cardio").tag(MuscleGroup?.some(.cardio))
                }
                .pickerStyle(.menu)

                ForEach(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Text(exercise.muscleGroup.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
