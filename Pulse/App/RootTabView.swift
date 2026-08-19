import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var gyms: [GymLocation]
    @State private var selectedTab = 0

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
        .task { seedExercisesIfNeeded() }
        .task(id: gyms.count) {
            services.location.monitor(gyms: gyms.map(\.region))
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .gymArrivalTapped)
                .receive(on: RunLoop.main)
        ) { notification in
            if let gymName = notification.object as? String {
                appState.handleArrival(gymName)
                selectedTab = 0
            }
        }
    }

    private func seedExercisesIfNeeded() {
        let descriptor = FetchDescriptor<Exercise>()
        let existing = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        for entry in ExerciseCatalog.entries {
            modelContext.insert(
                Exercise(
                    name: entry.name,
                    muscleGroup: MuscleGroup(rawValue: entry.group) ?? .chest,
                    isCardio: entry.cardio
                )
            )
        }
        try? modelContext.save()
    }
}
