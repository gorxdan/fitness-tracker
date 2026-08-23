import Foundation

enum MusicProvider: String, Codable {
    case spotify
    case appleMusic
}

struct PlaylistRef: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: MusicProvider
}

enum MusicError: Error {
    case notAvailable
    case notImplemented
}

/// The music seam views use. Wraps both providers; views never know which
/// is backing a playlist (see docs/ARCHITECTURE.md).
@MainActor
final class MusicController {
    private let spotify = SpotifyService()
    private let appleMusic = AppleMusicService()

    func isAvailable(_ provider: MusicProvider) async -> Bool {
        switch provider {
        case .spotify: await spotify.isAvailable()
        case .appleMusic: await appleMusic.isAvailable()
        }
    }

    /// True when Apple Music is authorized without prompting.
    var isAppleMusicAuthorized: Bool {
        appleMusic.isAuthorized
    }

    func fetchPlaylists(_ provider: MusicProvider) async throws -> [PlaylistRef] {
        switch provider {
        case .spotify: try await spotify.fetchPlaylists()
        case .appleMusic: try await appleMusic.fetchPlaylists()
        }
    }

    func play(_ playlist: PlaylistRef) async throws {
        switch playlist.provider {
        case .spotify: try await spotify.play(playlist)
        case .appleMusic: try await appleMusic.play(playlist)
        }
    }

    func pause() async {
        try? await appleMusic.pause()
        try? await spotify.pause()
    }
}
