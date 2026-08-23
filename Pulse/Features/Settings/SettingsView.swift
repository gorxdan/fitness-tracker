import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL
    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kilograms
    @State private var healthConnected: Bool?
    @State private var appleMusicConnected = false

    /// "Checking…" while the status query runs, so the button never shows
    /// "Connect Health" for an already-granted app.
    private var healthButtonTitle: String {
        switch healthConnected {
        case .some(true): "Health connected"
        case .some(false): "Connect Health"
        case nil: "Checking Health…"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    Button(healthButtonTitle) {
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
                        Button("Open Health settings") {
                            openURL(URL(string: "app-settings:")!)
                        }
                        .font(.footnote)
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
                    if services.location.access == .whenInUse {
                        Button("Allow Always for arrival prompts") {
                            Task { _ = await services.location.requestAlways() }
                        }
                    }
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
                    LabeledContent(
                        "Version",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                            as? String ?? "—"
                    )
                    LabeledContent("Target", value: "iOS 26.0")
                }
            }
            .navigationTitle("Settings")
            .task {
                healthConnected = await services.health.isAuthorized()
                appleMusicConnected = services.music.isAppleMusicAuthorized
            }
        }
    }
}
