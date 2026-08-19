import SwiftUI
import SwiftData

/// Full record of one workout: stats, HR, feel/pain, every set, notes, playlist.
struct WorkoutDetailView: View {
    @Environment(AppServices.self) private var services
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms
    let workout: Workout

    @State private var hrStats: HeartRateStats?

    private var groupedSets: [(exercise: Exercise, sets: [SetEntry])] {
        let all = workout.sets.sorted { $0.exercise?.name ?? "" < $1.exercise?.name ?? "" }
        return Dictionary(grouping: all, by: { $0.exercise })
            .compactMap { key, value in
                guard let exercise = key else { return nil }
                return (exercise, value.sorted { $0.index < $1.index })
            }
            .sorted { $0.exercise.name < $1.exercise.name }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(workout.startedAt, format: .dateTime.day().month().year().hour().minute())
                }
                if let ended = workout.endedAt {
                    LabeledContent("Duration") {
                        Text(
                            Duration.seconds(ended.timeIntervalSince(workout.startedAt)),
                            format: .units(allowed: [.hours, .minutes], width: .narrow)
                        )
                    }
                }
                LabeledContent("Volume") { Text(weightUnit.format(kg: workout.volumeKg)) }
                LabeledContent("Sets") { Text("\(workout.sets.count)") }
            }

            Section("Heart rate") {
                if let hrStats {
                    LabeledContent("Average") { Text("\(Int(hrStats.averageBPM.rounded())) bpm") }
                    LabeledContent("Peak") { Text("\(Int(hrStats.peakBPM.rounded())) bpm") }
                } else {
                    Text("No heart-rate data for this session")
                        .foregroundStyle(.secondary)
                }
            }

            if workout.feelRating != nil || (workout.painLevel ?? 0) > 0 {
                Section("How it went") {
                    if let feel = workout.feelRating {
                        LabeledContent("Feel") { Text("\(feel)/5") }
                    }
                    if let pain = workout.painLevel, pain > 0 {
                        LabeledContent("Pain") {
                            Text(["None", "Mild", "Moderate", "Severe"][min(pain, 3)])
                        }
                        if let location = workout.painLocation, !location.isEmpty {
                            LabeledContent("Where") { Text(location) }
                        }
                    }
                }
            }

            ForEach(groupedSets, id: \.exercise.id) { group in
                Section(group.exercise.name) {
                    ForEach(group.sets) { set in
                        HStack {
                            Text("Set \(set.index + 1)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if group.exercise.isCardio {
                                Text("\(set.reps) min") +
                                Text(set.distanceKm.map { " · \(String(format: "%.1f", $0)) km" } ?? "")
                            } else {
                                Text("\(set.reps) × \(weightUnit.format(kg: set.weightKg))")
                            }
                        }
                        .font(.subheadline.monospacedDigit())
                    }
                }
            }

            if let playlistName = workout.musicPlaylistName, !playlistName.isEmpty {
                Section("Music") {
                    Label(playlistName, systemImage: "music.note.list")
                }
            }

            if !workout.notes.isEmpty {
                Section("Notes") {
                    Text(workout.notes)
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: workout.id) {
            if let ended = workout.endedAt {
                hrStats = await services.health.heartRateStats(
                    start: workout.startedAt, end: ended
                )
            }
        }
    }
}
