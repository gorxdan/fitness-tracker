import SwiftUI
import SwiftData

/// Mid-workout logging screen: exercises as sections, sets as rows, one-tap repeat.
struct WorkoutSessionView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var model = SessionModel()
    @State private var pickingExercise = false
    @State private var pickingPlaylist = false
    @State private var confirmingFinish = false
    @State private var musicMessage: String?

    private let prefillTitle: String?

    init(prefillTitle: String? = nil) {
        self.prefillTitle = prefillTitle
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                ForEach(model.slots) { slot in
                    slotSection(slot)
                }
                .onDelete { _ in }
                if model.slots.isEmpty {
                    ContentUnavailableView(
                        "No exercises yet",
                        systemImage: "plus.circle.dashed",
                        description: Text("Add your first exercise to start logging sets.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { appState.sessionActive = false }
                        .foregroundStyle(.secondary)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        pickingExercise = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    Button("Finish") { confirmingFinish = true }
                        .disabled(!model.canFinish)
                        .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $pickingExercise) {
                ExercisePickerView { exercise in
                    model.addSlot(for: exercise)
                }
            }
            .sheet(isPresented: $pickingPlaylist) {
                PlaylistPickerView(current: model.playlist) { playlist in
                    if let playlist {
                        model.playlist = playlist
                        Task { await startPlayback(playlist) }
                    } else {
                        model.playlist = nil
                        Task { await services.music.pause() }
                    }
                }
            }
            .sheet(isPresented: $confirmingFinish) {
                WorkoutSummaryView(model: model, fallbackTitle: prefillTitle)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.startedAt, style: .timer)
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("\(model.doneSetCount) sets · \(Int(model.totalVolumeKg.rounded())) kg")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                playlistButton
            }
            if let musicMessage {
                Text(musicMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playlistButton: some View {
        Button {
            pickingPlaylist = true
        } label: {
            Image(systemName: model.playlist == nil ? "music.note.list" : "music.note")
                .font(.title3)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(model.playlist.map { "Playlist \($0.name)" } ?? "Choose playlist")
    }

    @ViewBuilder
    private func slotSection(_ slot: SessionModel.Slot) -> some View {
        Section {
            ForEach(slot.sets) { set in
                setRow(set, in: slot)
                    .swipeActions {
                        Button(role: .destructive) {
                            model.removeSet(set.id, in: slot.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Button {
                model.addSet(to: slot.id)
            } label: {
                Label(
                    slot.sets.isEmpty ? "Add set" : "Repeat last set",
                    systemImage: slot.sets.isEmpty ? "plus" : "plus.square.on.square"
                )
            }
        } header: {
            HStack {
                Text(slot.exercise.name)
                if slot.exercise.isCardio {
                    Text("cardio")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: Capsule())
                }
                Spacer()
                Button(role: .destructive) {
                    model.removeSlot(slot.id)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func setRow(_ set: SessionModel.SetDraft, in slot: SessionModel.Slot) -> some View {
        HStack(spacing: 12) {
            Button {
                model.toggleDone(set.id, in: slot.id)
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isDone ? .teal : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(set.isDone ? "Mark set unlogged" : "Mark set logged")

            if slot.exercise.isCardio {
                numberField("min", value: intField(set.id, slot.id, \.reps))
                numberField("km", value: optionalField(set.id, slot.id, \.distanceKm))
            } else {
                numberField("reps", value: intField(set.id, slot.id, \.reps))
                Text("×").foregroundStyle(.secondary)
                numberField("kg", value: doubleField(set.id, slot.id, \.weightKg))
            }
        }
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        TextField(label, value: value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 64)
            .textFieldStyle(.roundedBorder)
    }

    // MARK: - Field bindings

    private func intField(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SessionModel.SetDraft, Int>
    ) -> Binding<Double> {
        Binding(
            get: { Double(model.setValue(setID, slotID, keyPath)) },
            set: { model.setValue(setID, slotID, keyPath, Int($0)) }
        )
    }

    private func doubleField(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SessionModel.SetDraft, Double>
    ) -> Binding<Double> {
        Binding(
            get: { model.setDouble(setID, slotID, keyPath) },
            set: { model.setDouble(setID, slotID, keyPath, $0) }
        )
    }

    private func optionalField(
        _ setID: UUID, _ slotID: UUID, _ keyPath: WritableKeyPath<SessionModel.SetDraft, Double?>
    ) -> Binding<Double> {
        Binding(
            get: { model.setOptional(setID, slotID, keyPath) ?? 0 },
            set: { model.setOptional(setID, slotID, keyPath, $0) }
        )
    }

    private func startPlayback(_ playlist: PlaylistRef) async {
        do {
            try await services.music.play(playlist)
            model.isPlaying = true
            musicMessage = nil
        } catch {
            model.isPlaying = false
            musicMessage = playlist.provider == .spotify
                ? "Spotify connects in the Mac build phase — playlist saved."
                : "Couldn't start playback: \(playlist.name)"
        }
    }
}
