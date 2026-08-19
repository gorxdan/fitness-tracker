import SwiftUI

struct SettingsView: View {
    let health: any HealthReading
    @State private var healthGranted: Bool?

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    Button("Grant Health access") {
                        Task {
                            healthGranted = await health.requestAuthorization()
                        }
                    }
                    if let granted = healthGranted {
                        Label(
                            granted ? "Health connected" : "Health not authorized",
                            systemImage: granted ? "checkmark.circle.fill" : "xmark.circle"
                        )
                    }
                }
                Section("Music") {
                    Label("Spotify — connects in build phase", systemImage: "music.note.list")
                    Label("Apple Music — connects in build phase", systemImage: "music.note")
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Target", value: "iOS 26.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
