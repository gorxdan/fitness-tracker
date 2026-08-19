import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms
    @State private var healthConnected: Bool?
    @State private var appleMusicConnected = false

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    Button(healthConnected == true ? "Health connected" : "Connect Health") {
                        Task {
                            _ = await services.health.requestAuthorization()
                            healthConnected = await services.health.isAuthorized()
                        }
                    }
                    if healthConnected == false {
                        Label("Not authorized — workouts still work without it",
                              systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Music") {
                    Button(appleMusicConnected ? "Apple Music connected" : "Connect Apple Music") {
                        Task {
                            appleMusicConnected = await services.music.isAvailable(.appleMusic)
                        }
                    }
                    LabeledContent("Spotify") {
                        Text("Mac build phase")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Location") {
                    NavigationLink("Gyms & arrival prompts") { GymsView() }
                    Text(services.location.access.footerText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Units") {
                    Picker("Weight unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Target", value: "iOS 26.0")
                }
            }
            .navigationTitle("Settings")
            .task {
                healthConnected = await services.health.isAuthorized()
                appleMusicConnected = services.music.appleMusicStatus
            }
        }
    }
}
