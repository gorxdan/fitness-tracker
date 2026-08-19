import Foundation

/// Spotify integration via the Spotify iOS SDK (remote control of the installed app).
/// SDK package + auth are added in the build phase — see docs/INTEGRATIONS.md.
@MainActor
final class SpotifyService {
    func isAvailable() async -> Bool {
        false // Build phase: check installed Spotify app + session.
    }

    func fetchPlaylists() async throws -> [PlaylistRef] {
        throw MusicError.notImplemented
    }

    func play(_ playlist: PlaylistRef) async throws {
        throw MusicError.notImplemented
    }

    func pause() async throws {
        throw MusicError.notImplemented
    }
}
