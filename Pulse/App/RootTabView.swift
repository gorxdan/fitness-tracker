import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var gyms: [GymLocation]
    @State private var selectedTab = 0
    @AppStorage("healthAuthorizationRequested") private var healthAuthRequested = false

    var body: some View {
        @Bindable var session = appState
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .sheet(isPresented: $session.sessionActive) {
            WorkoutSessionView(prefillTitle: session.sessionPrefillTitle)
                .interactiveDismissDisabled()
        }
        .task {
            seedExercisesIfNeeded()
            requestHealthAuthorizationOnceIfNeeded()
        }
        .task(id: gyms.count) {
            services.location.monitor(gyms: gyms.map(\.region))
        }
        .task {
            // async/await instead of a Combine subscription (repo rule).
            // Arrival taps are already posted on the main actor by the
            // ArrivalNotificationDelegate, so no further hop is needed.
            for await notification in NotificationCenter.default.notifications(
                named: .gymArrivalTapped
            ) {
                if let gymName = notification.object as? String {
                    appState.handleArrival(gymName)
                    selectedTab = 0
                }
            }
        }
    }

    /// Idempotent by name collision (docs/DATA_MODEL.md): later catalog
    /// additions seed into existing stores too, never duplicating rows.
    private func seedExercisesIfNeeded() {
        let existing = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let known = Set(existing.map(\.name))
        var inserted = false
        for entry in ExerciseCatalog.entries where !known.contains(entry.name) {
            modelContext.insert(
                Exercise(
                    name: entry.name,
                    muscleGroup: MuscleGroup(rawValue: entry.group) ?? .chest,
                    isCardio: entry.cardio
                )
            )
            inserted = true
        }
        if inserted { try? modelContext.save() }
    }

    /// Health permission is requested once at first launch (docs/INTEGRATIONS.md);
    /// Settings keeps the status row and the re-prompt path afterwards.
    private func requestHealthAuthorizationOnceIfNeeded() {
        guard !healthAuthRequested else { return }
        healthAuthRequested = true
        Task { _ = await services.health.requestAuthorization() }
    }
}
