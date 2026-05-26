import SwiftUI

struct ContentView: View {
    @EnvironmentObject var spotify: SpotifyRepository
    @StateObject private var viewModel = PlayerViewModel()
    @State private var trackCardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            if !spotify.isAuthenticated {
                loginView
            } else if let track = viewModel.currentTrack {
                VStack(spacing: 16) {
                    TrackCardView(
                        track: track,
                        genres: viewModel.genres,
                        isLoadingGenres: viewModel.isLoadingGenres
                    )
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        trackCardHeight = height
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewModel.isDescriptionExpanded = false
                        }
                    }

                    if let primaryGenre = viewModel.genres.first {
                        GenreDescriptionCardView(
                            primaryGenre: primaryGenre,
                            description: viewModel.genreDescription,
                            isLoading: viewModel.isLoadingDescription
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                viewModel.isDescriptionExpanded = true
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .offset(y: viewModel.isDescriptionExpanded ? -(trackCardHeight + 24) : 0)
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .background(Color(hex: "#1A1A1A").ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if spotify.isAuthenticated {
                viewModel.startPolling()
            }
        }
        .onChange(of: spotify.isAuthenticated) { authenticated in
            if authenticated {
                viewModel.startPolling()
            } else {
                viewModel.stopPolling()
            }
        }
    }

    private var loginView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(Color.accentColor)

            Text("GenRemedy")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Discover the genre of what you're listening to")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first
                else { return }
                spotify.startOAuth(presentationAnchor: window)
            } label: {
                Label("Connect Spotify", systemImage: "link")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#1DB954"))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Nothing playing")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Play a track in Spotify to get started")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Sign Out") {
                spotify.signOut()
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.top, 32)
            Spacer()
        }
        .padding()
    }
}
