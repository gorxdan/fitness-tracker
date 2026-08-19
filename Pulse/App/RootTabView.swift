import SwiftUI

struct RootTabView: View {
    @State private var health = HealthKitService()
    @State private var music = MusicController()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView(health: health)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environment(health)
        .environment(music)
    }
}
