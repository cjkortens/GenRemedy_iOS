import SwiftUI

struct GenreDescriptionCardView: View {
    let primaryGenre: String
    let description: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(primaryGenre.capitalized)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.brandPurple)

            Text(isLoading || description.isEmpty ? "Loading description..." : description)
                .font(.subheadline)
                .foregroundColor(isLoading || description.isEmpty ? .gray : .white.opacity(0.85))
                .lineSpacing(3)
                .lineLimit(15)
        }
        .padding(20)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(20)
    }
}
