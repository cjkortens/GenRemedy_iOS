import Foundation

struct SpotifyUserTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct CurrentlyPlayingResponse: Codable {
    let isPlaying: Bool
    let item: TrackItem?
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
    }
}

struct TrackItem: Codable {
    let id: String
    let name: String
    let artists: [ArtistItem]
    let album: AlbumItem?
}

struct AlbumItem: Codable {
    let name: String
    let releaseDate: String?
    let images: [AlbumImage]
    enum CodingKeys: String, CodingKey {
        case name
        case releaseDate = "release_date"
        case images
    }
}

struct AlbumImage: Codable {
    let url: String
    let width: Int?
    let height: Int?
}

struct ArtistItem: Codable {
    let id: String
    let name: String
}

struct GenreEntry {
    let trackId: String
    let genre1: String
    let genre2: String
    let genre3: String
    let lastUpdated: TimeInterval
}
