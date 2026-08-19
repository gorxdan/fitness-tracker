import SwiftUI

/// Attaches a playlist to the running workout. Apple Music lists real playlists;
/// Spotify is stubbed until the SDK lands (message shown inline, workout continues).
struct PlaylistPickerView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var provider: MusicProvider = .appleMusic
    @State private var playlists: [PlaylistRef] = []
    @State private var statusText: String?
    @State private var loading = false

    let current: PlaylistRef?
    let onSelect: (PlaylistRef?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Picker("Provider", selection: $provider) {
                    Text("Apple Music").tag(MusicProvider.appleMusic)
                    Text("Spotify").tag(MusicProvider.spotify)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .onChange(of: provider) {
                    Task { await load() }
                }

                if loading {
                    HStack {
                        ProgressView()
                        Text("Loading playlists…")
                    }
                } else if let statusText {
                    Text(statusText).foregroundStyle(.secondary)
                } else {
                    ForEach(playlists) { playlist in
                        Button {
                            onSelect(playlist)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: playlist.provider == .appleMusic
                                    ? "music.note" : "music.note.list")
                                    .foregroundStyle(.secondary)
                                Text(playlist.name)
                                Spacer()
                                if current?.id == playlist.id {
                                    Image(systemName: "checkmark").foregroundStyle(.teal)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if current != nil {
                    Button("None") {
                        onSelect(nil)
                        dismiss()
                    }
                }
                Button("Done") { dismiss() }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        statusText = nil
        defer { loading = false }
        do {
            playlists = try await services.music.fetchPlaylists(provider)
            if playlists.isEmpty {
                statusText = "No playlists found in \(provider == .appleMusic ? "Apple Music" : "Spotify")."
            }
        } catch {
            if provider == .spotify {
                statusText = "Spotify connects in the Mac build phase — playlists from Apple Music work today."
            } else {
                statusText = "Apple Music isn't authorized. Connect it in Settings first."
            }
        }
    }
}
