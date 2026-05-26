import SwiftUI

struct TrackCardView: View {
    let track: TrackItem
    let genres: [String]
    let isLoadingGenres: Bool

    private var albumArtURL: URL? {
        guard let urlStr = track.album?.images.first?.url else { return nil }
        return URL(string: urlStr)
    }

    private var artistNames: String {
        track.artists.map(\.name).joined(separator: ", ")
    }

    private var releaseYear: String {
        String(track.album?.releaseDate?.prefix(4) ?? "")
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            AsyncImage(url: albumArtURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .center, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(artistNames)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                if !releaseYear.isEmpty {
                    Text(releaseYear)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)

            if isLoadingGenres {
                ProgressView()
                    .tint(.white)
            } else if !genres.isEmpty {
                HStack(spacing: 8) {
                    ForEach(genres.prefix(3), id: \.self) { genre in
                        GenreChip(text: genre)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(20)
    }
}

private let genrePurple = Color(hex: "#7C3AED")

struct GenreChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(genrePurple)
            .clipShape(Capsule())
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
