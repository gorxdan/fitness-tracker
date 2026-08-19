import Foundation
import MusicKit

/// Apple Music integration via MusicKit. Playlist picker + playback arrive in the build phase.
final class AppleMusicService {
    func isAvailable() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
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
