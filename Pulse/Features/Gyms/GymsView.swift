import MapKit
import SwiftData
import SwiftUI

/// Saved gyms and geofence monitoring. Arrival prompts appear when entering a radius.
struct GymsView: View {
    @Query(sort: \GymLocation.name) private var gyms: [GymLocation]
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var addingGym = false

    var body: some View {
        List {
            if gyms.isEmpty {
                ContentUnavailableView(
                    "No gyms saved",
                    systemImage: "mappin.and.ellipse",
                    description: Text(
                        "Save a gym to get an offer to start your workout on arrival."
                    )
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(gyms) { gym in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gym.name).font(.headline)
                        Text(
                            String(
                                format: "%.4f, %.4f · %d m radius",
                                gym.latitude, gym.longitude, Int(gym.radiusMeters)
                            )
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
            }

            Section {
                Button("Add Gym") { addingGym = true }
            } footer: {
                Text(services.location.access.footerText)
            }
        }
        .navigationTitle("Gyms")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingGym) {
            GymEditorView()
        }
        .onChange(of: gyms.count) {
            services.location.monitor(gyms: gyms.map(\.region))
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(gyms[index])
        }
        try? modelContext.save()
        services.location.monitor(gyms: gyms.map(\.region))
    }
}

extension GymLocation {
    var region: GymRegion {
        GymRegion(
            id: id, name: name, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters
        )
    }
}

/// Add a gym: name, coordinates (current location or typed), radius.
struct GymEditorView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var latitude = 0.0
    @State private var longitude = 0.0
    @State private var radius = 100.0
    @State private var locating = false
    @State private var locationMessage: String?

    /// (0, 0) is the unset sentinel; range checks catch typos before
    /// CLCircularRegion silently refuses to monitor the region.
    private var coordinateValid: Bool {
        (-90.0...90.0).contains(latitude)
            && (-180.0...180.0).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Ironworks)", text: $name)
                }

                Section("Location") {
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        if locating {
                            HStack {
                                ProgressView()
                                Text("Locating…")
                            }
                        } else {
                            Label("Use current location", systemImage: "location")
                        }
                    }
                    .disabled(locating)
                    if let locationMessage {
                        Text(locationMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    latitudeField
                    longitudeField
                }

                Section {
                    LabeledContent("Radius") { Text("\(Int(radius)) m") }
                    Slider(value: $radius, in: 50...300, step: 25)
                } footer: {
                    Text("You'll get one notification on entering the radius.")
                }

                if latitude != 0 || longitude != 0 {
                    Section("Map") {
                        Map {
                            Marker(
                                name.isEmpty ? "Gym" : name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: latitude, longitude: longitude
                                )
                            )
                        }
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                }
            }
            .navigationTitle("New Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .disabled(name.isEmpty || !coordinateValid)
            }
        }
    }

    private var latitudeField: some View {
        HStack {
            Text("Latitude")
            Spacer()
            TextField("0.0", value: $latitude, format: .number)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 130)
        }
    }

    private var longitudeField: some View {
        HStack {
            Text("Longitude")
            Spacer()
            TextField("0.0", value: $longitude, format: .number)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 130)
        }
    }

    private func useCurrentLocation() async {
        locating = true
        defer { locating = false }
        let status = await services.location.requestWhenInUse()
        guard services.location.access.isPermitted else {
            locationMessage = "Location permission needed — enable it in Settings."
            return
        }
        do {
            let location = try await services.location.currentLocation()
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            locationMessage = nil
        } catch {
            locationMessage = "Couldn't get a location fix: \(error.localizedDescription)"
        }
    }

    private func save() {
        let gym = GymLocation(
            name: name, latitude: latitude, longitude: longitude, radiusMeters: radius
        )
        modelContext.insert(gym)
        try? modelContext.save()
        Task {
            _ = await LocationService.requestNotificationAuthorization()
        }
        dismiss()
    }
}
