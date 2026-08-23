import SwiftData
import SwiftUI

/// Finish flow: title, feel, pain, notes, HR summary — then persists everything
/// (SwiftData + HealthKit) and closes the session.
struct WorkoutSummaryView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms

    let model: SessionModel
    let fallbackTitle: String?

    @State private var title = ""
    @State private var feel = 3
    @State private var pain = 0
    @State private var painLocation = ""
    @State private var notes = ""
    @State private var hrStats: HeartRateStats?
    @State private var bodyMassKg: Double?
    @State private var saving = false

    /// When Finish was tapped. Notes can take minutes to write; the recorded
    /// duration, HR window, and HealthKit end stop here, not at Save.
    @State private var sessionEnd: Date

    private let painLabels = ["None", "Mild", "Moderate", "Severe"]

    init(model: SessionModel, fallbackTitle: String?) {
        self.model = model
        self.fallbackTitle = fallbackTitle
        _sessionEnd = State(initialValue: Date.now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Title", text: $title)
                    LabeledContent("Duration") {
                        Text(
                            Duration.seconds(sessionEnd.timeIntervalSince(model.startedAt)),
                            format: .units(allowed: [.hours, .minutes], width: .narrow)
                        )
                    }
                    LabeledContent("Sets logged") { Text("\(model.doneSetCount)") }
                    LabeledContent("Volume") {
                        Text(weightUnit.format(kg: model.totalVolumeKg))
                    }
                }

                Section("Heart rate") {
                    if let hrStats {
                        LabeledContent("Average") {
                            Text("\(Int(hrStats.averageBPM.rounded())) bpm")
                        }
                        LabeledContent("Peak") { Text("\(Int(hrStats.peakBPM.rounded())) bpm") }
                    } else {
                        Label("No heart-rate data for this session", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("How did it feel?") {
                    Picker("Feel", selection: $feel) {
                        ForEach(1...5, id: \.self) { value in
                            Text(feelLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Pain") {
                    Picker("Pain level", selection: $pain) {
                        ForEach(0..<4, id: \.self) { Text(painLabels[$0]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if pain > 0 {
                        TextField("Where? (e.g. left knee)", text: $painLocation)
                    }
                }

                Section("Notes") {
                    TextField("Anything worth remembering…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if model.playlist != nil, let playlist = model.playlist {
                    Section("Music") {
                        Label(
                            playlist.name,
                            systemImage: playlist.provider == .appleMusic
                                ? "music.note" : "music.note.list")
                    }
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { dismiss() }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Workout").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
                .padding()
            }
            .onAppear(perform: loadDefaults)
            .task { await loadHealthData() }
        }
    }

    // MARK: - Data

    private func loadDefaults() {
        let derived = model.defaultTitle
        title = derived == "Workout" ? (fallbackTitle ?? derived) : derived
    }

    private func loadHealthData() async {
        hrStats = await services.health.heartRateStats(
            start: model.startedAt, end: sessionEnd
        )
        bodyMassKg = await services.health.latestBodyMassKg()
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let end = sessionEnd

        let playlist = model.playlist
        let workout = Workout(
            title: title.isEmpty ? model.defaultTitle : title,
            startedAt: model.startedAt,
            endedAt: end,
            feelRating: feel,
            painLevel: pain,
            painLocation: pain > 0 && !painLocation.isEmpty ? painLocation : nil,
            notes: notes,
            musicProvider: playlist?.provider,
            musicPlaylistID: playlist?.id,
            musicPlaylistName: playlist?.name
        )
        modelContext.insert(workout)

        for slot in model.slots {
            // Renumber at save time so skipped drafts don't leave "Set 1, Set 3"
            // gaps in the detail view.
            var index = 0
            for draft in slot.sets where draft.isDone {
                let entry = SetEntry(
                    index: index,
                    reps: draft.reps,
                    weightKg: draft.weightKg,
                    distanceKm: draft.distanceKm,
                    exercise: slot.exercise
                )
                entry.workout = workout
                modelContext.insert(entry)
                index += 1
            }
        }
        try? modelContext.save()

        // Rough energy estimate × body mass (80 kg assumed without Health data).
        // kcal/min ≈ 0.0175 × MET × kg; MET 5 for strength, 7 for sustained cardio.
        let cardioOnly = !model.slots.isEmpty && model.slots.allSatisfy(\.exercise.isCardio)
        let met = cardioOnly ? 7.0 : 5.0
        let massKg = bodyMassKg ?? 80
        let minutes = end.timeIntervalSince(model.startedAt) / 60
        let kcal = minutes * 0.0175 * met * massKg
        try? await services.health.saveWorkout(
            start: model.startedAt, end: end, activeEnergyKcal: kcal,
            activityType: cardioOnly ? .mixedCardio : .traditionalStrengthTraining
        )

        await services.music.pause()
        appState.sessionActive = false
        dismiss()
    }

    private func feelLabel(_ value: Int) -> String {
        switch value {
        case 1: "Awful"
        case 2: "Poor"
        case 3: "OK"
        case 4: "Good"
        default: "Great"
        }
    }
}
