import SwiftUI

@MainActor
@Observable
class PlayerViewModel {
    var currentTrack: TrackItem?
    var genres: [String] = []
    var genreDescription: String = ""
    var isLoadingGenres = false
    var isLoadingDescription = false
    var isDescriptionExpanded = false
    var errorMessage: String?

    private var lastTrackId: String?
    private var lastPrimaryGenre: String?
    private var pollingTask: Task<Void, Never>?

    private let spotify = SpotifyRepository.shared
    private let gemini = GeminiRepository()
    private let genreLibrary = GenreLibraryRepository.shared
    private let genreDescriptions = GenreDescriptionRepository.shared

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchCurrentTrack()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func fetchCurrentTrack() async {
        do {
            guard let response = try await spotify.fetchCurrentlyPlaying(),
                  response.isPlaying,
                  let track = response.item
            else { return }

            if track.id != lastTrackId {
                currentTrack = track
                lastTrackId = track.id
                genres = []
                genreDescription = ""
                isDescriptionExpanded = false
                await resolveGenres(for: track)
            }
        } catch {
            errorMessage = "Fetch error: \(error.localizedDescription)"
        }
    }

    private func resolveGenres(for track: TrackItem) async {
        isLoadingGenres = true

        if let cached = await genreLibrary.fetchGenres(trackId: track.id) {
            genres = cached
        } else {
            do {
                let artistName = track.artists.map(\.name).joined(separator: ", ")
                let fetched = try await gemini.classifyGenres(trackName: track.name, artistName: artistName)
                genres = fetched
                genreLibrary.saveGenres(trackId: track.id, genres: fetched)
            } catch {
                errorMessage = "Genre error: \(error.localizedDescription)"
                isLoadingGenres = false
                return
            }
        }

        isLoadingGenres = false

        if let primary = genres.first, primary != lastPrimaryGenre {
            lastPrimaryGenre = primary
            await resolveDescription(for: primary)
        }
    }

    private func resolveDescription(for genre: String) async {
        isLoadingDescription = true
        defer { isLoadingDescription = false }

        if let cached = await genreDescriptions.fetchDescription(genre: genre) {
            genreDescription = cached
        } else {
            do {
                let desc = try await gemini.describeGenre(genre)
                genreDescription = desc
                genreDescriptions.saveDescription(genre: genre, description: desc)
            } catch {
                errorMessage = "Description error: \(error.localizedDescription)"
            }
        }
    }
}
