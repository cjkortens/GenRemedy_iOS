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
            .frame(maxWidth: 320)
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
                ChipFlow(spacing: 8) {
                    ForEach(genres.prefix(3), id: \.self) { genre in
                        GenreChip(text: genre)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(20)
    }
}

private let genrePurple = Color.brandPurple

struct GenreChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(genrePurple)
            .clipShape(Capsule())
    }
}

private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(subviews: subviews, width: proposal.width ?? 0)
        let height = rows.map { rowHeight($0) }.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(subviews: subviews, width: bounds.width) {
            let rw = row.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +) + CGFloat(max(0, row.count - 1)) * spacing
            var x = bounds.minX + (bounds.width - rw) / 2
            let rh = rowHeight(row)
            for subview in row {
                let s = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y + (rh - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rh + spacing
        }
    }

    private func makeRows(subviews: Subviews, width: CGFloat) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        for sub in subviews {
            let w = sub.sizeThatFits(.unspecified).width
            if !rows[rows.count - 1].isEmpty && x + w > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(sub)
            x += w + spacing
        }
        return rows.filter { !$0.isEmpty }
    }

    private func rowHeight(_ row: [LayoutSubview]) -> CGFloat {
        row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
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

    // Brand purples sampled from the GenRemedy logo (magenta-leaning orchid),
    // used everywhere the UI needs the accent so the hue stays consistent.
    static let brandPurple = Color(hex: "#9E47A4")      // mid: chips, accents
    static let brandPurpleLight = Color(hex: "#B265CC") // gradient highlight
    static let brandPurpleDeep = Color(hex: "#82397F")  // gradient shadow
}
