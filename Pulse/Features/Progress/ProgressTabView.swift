import SwiftUI
import SwiftData
import Charts

/// Progress tab: volume, per-exercise trend, body weight/BMI, heart trends, history.
/// All charts are Swift Charts with system styling, per docs/ARCHITECTURE.md.
struct ProgressTabView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Environment(AppServices.self) private var services
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms

    private enum ChartTab: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case exercises = "Exercises"
        case body = "Body"
        case heart = "Heart"
        var id: String { rawValue }
    }

    @State private var tab: ChartTab = .volume
    @State private var range: StatRange = .threeMonths
    @State private var selectedExercise: String?
    @State private var weightSeries: [DatedValue] = []
    @State private var restingSeries: [DatedValue] = []
    @State private var hrvSeries: [DatedValue] = []
    @State private var latestMassKg: Double?
    @State private var heightM: Double?
    @State private var loadingHealth = true

    private var records: [SetRecord] { workouts.flatMap(\.records) }
    private var rangeInterval: DateInterval {
        let full = range.intervalEnding()
        return DateInterval(
            start: workouts.last.map { min(full.start, $0.startedAt) } ?? full.start,
            end: full.end
        )
    }
    private var exercisesInRange: [String] {
        Set(records.filter { rangeInterval.contains($0.date) }.map(\.exerciseName)).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Range", selection: $range) {
                    ForEach(StatRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch tab {
                case .volume: volumeSection
                case .exercises: exerciseSection
                case .body: bodySection
                case .heart: heartSection
                }
            }
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .safeAreaInset(edge: .bottom) {
                Picker("Chart", selection: $tab) {
                    ForEach(ChartTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .task(id: range) { await loadHealthSeries() }
        }
    }

    // MARK: - Volume

    @ViewBuilder
    private var volumeSection: some View {
        Section {
            let points = WorkoutStats.weeklyVolume(records, in: rangeInterval)
            if points.isEmpty {
                emptyChart("Log strength sets to see weekly volume.")
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Volume", weightUnit.fromKg(point.volumeKg))
                    )
                    .foregroundStyle(by: .value("Muscle group", point.muscleGroup.capitalized))
                }
                .chartXAxis(.automatic)
                .frame(height: 260)
                .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
            }
        } header: {
            Text("Weekly volume by muscle group (\(weightUnit.label))").textCase(nil)
        }
    }

    // MARK: - Exercises

    @ViewBuilder
    private var exerciseSection: some View {
        Section {
            if exercisesInRange.isEmpty {
                emptyChart("No exercises logged in this range.")
            } else {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(exercisesInRange, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)

                if let name = selectedExercise ?? exercisesInRange.first {
                    trendChart(for: name)
                }
            }
        } header: {
            Text("Best estimated 1RM per session").textCase(nil)
        } footer: {
            Text("Epley estimate: weight × (1 + reps/30).")
        }
    }

    @ViewBuilder
    private func trendChart(for exercise: String) -> some View {
        let series = WorkoutStats.oneRepMaxSeries(
            exerciseName: exercise, in: records.filter { rangeInterval.contains($0.date) }
        )
        if series.isEmpty {
            emptyChart("No strength sets for \(exercise) in this range.")
        } else {
            Chart(series) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", weightUnit.fromKg(point.value))
                )
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("e1RM", weightUnit.fromKg(point.value))
                )
                .interpolationMethod(.monotone)
            }
            .frame(height: 220)
            .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodySection: some View {
        Section {
            if loadingHealth {
                ProgressView("Loading from Health…")
            } else if weightSeries.isEmpty {
                emptyChart("No weight samples in Health for this range.")
            } else {
                Chart(weightSeries.filter { rangeInterval.contains($0.date) }) { point in
                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("Weight", weightUnit.fromKg(point.value))
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Week", point.date),
                        y: .value("Weight", weightUnit.fromKg(point.value))
                    )
                }
                .frame(height: 200)
                .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
            }

            if let mass = latestMassKg, let height = heightM {
                let bmi = FitnessMath.bmi(massKg: mass, heightM: height)
                LabeledContent("BMI") {
                    Text("\(String(format: "%.1f", bmi)) · \(FitnessMath.bmiCategory(for: bmi).label)")
                }
            } else {
                LabeledContent("BMI") { Text("Needs height + weight in Health") }
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Weight trend (weekly average, \(weightUnit.label))").textCase(nil)
        }
    }

    // MARK: - Heart

    @ViewBuilder
    private var heartSection: some View {
        Section {
            if loadingHealth {
                ProgressView("Loading from Health…")
            } else if restingSeries.isEmpty {
                emptyChart("No resting heart-rate data in Health for this range.")
            } else {
                Chart(restingSeries.filter { rangeInterval.contains($0.date) }) { point in
                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("Resting HR", point.value)
                    )
                    .interpolationMethod(.monotone)
                }
                .frame(height: 160)
                .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
            }
        } header: {
            Text("Resting heart rate (bpm, weekly average)").textCase(nil)
        }

        Section {
            if loadingHealth {
                EmptyView()
            } else if hrvSeries.isEmpty {
                Text("No heart-rate variability data in Health for this range.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(hrvSeries.filter { rangeInterval.contains($0.date) }) { point in
                    LineMark(
                        x: .value("Week", point.date),
                        y: .value("HRV", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.teal)
                }
                .frame(height: 160)
                .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
            }
        } header: {
            Text("Heart-rate variability (ms SDNN, weekly average)").textCase(nil)
        }
    }

    // MARK: - Helpers

    private func emptyChart(_ text: String) -> some View {
        Label(text, systemImage: "chart.dots.scatter")
            .foregroundStyle(.secondary)
            .font(.subheadline)
    }

    private func loadHealthSeries() async {
        loadingHealth = true
        defer { loadingHealth = false }
        let interval = rangeInterval
        async let series = services.health.progressSeries(start: interval.start, end: interval.end)
        async let mass = services.health.latestBodyMassKg()
        async let height = services.health.heightMeters()
        let loaded = await series
        weightSeries = loaded.weightKg
        restingSeries = loaded.restingHeartRate
        hrvSeries = loaded.heartRateVariability
        latestMassKg = await mass
        heightM = await height
        if selectedExercise == nil {
            selectedExercise = exercisesInRange.first
        }
    }
}

/// History list, linked from Progress toolbar-less header row (kept in same file: tiny).
struct WorkoutHistoryView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms

    var body: some View {
        List(workouts) { workout in
            NavigationLink {
                WorkoutDetailView(workout: workout)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title).font(.headline)
                    Text(workout.startedAt, format: .dateTime.day().month().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
