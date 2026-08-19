import Foundation
import MusicKit

/// Apple Music via MusicKit. MainActor: ApplicationMusicPlayer is MainActor-isolated.
/// Spotify stays a stub until the SDK is added on macOS (see docs/INTEGRATIONS.md).
@MainActor
final class AppleMusicService {
    var isAuthorized: Bool {
        MusicAuthorization.status == .authorized
    }

    /// Requests permission if not yet determined; returns availability.
    func isAvailable() async -> Bool {
        if isAuthorized { return true }
        return await MusicAuthorization.request() == .authorized
    }

    func fetchPlaylists() async throws -> [PlaylistRef] {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()
        return response.items.map {
            PlaylistRef(id: $0.id.rawValue, name: $0.name, provider: .appleMusic)
        }
    }

    func play(_ playlist: PlaylistRef) async throws {
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, memberOf: [MusicItemID(playlist.id)])
        guard let found = try await request.response().items.first else {
            throw MusicError.notAvailable
        }
        let player = ApplicationMusicPlayer.shared
        player.queue = ApplicationMusicPlayer.Queue(for: found)
        try await player.play()
    }

    func pause() async throws {
        ApplicationMusicPlayer.shared.pause()
    }
}
