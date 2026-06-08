import SwiftUI

struct ContentView: View {
    @Environment(SpotifyRepository.self) var spotify
    @State private var viewModel = PlayerViewModel()
    @State private var trackCardHeight: CGFloat = 0
    @State private var descriptionCardHeight: CGFloat = 0

    // Layout constants shared between the VStack's padding/spacing and the
    // expand offset math, so the two can't drift apart across devices.
    private enum Layout {
        static let cardSpacing: CGFloat = 16
        static let topPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }

    var body: some View {
        ZStack(alignment: .top) {
            if !spotify.isAuthenticated {
                loginView
            } else {
                playerView
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
        .onChange(of: spotify.isAuthenticated) { _, authenticated in
            if authenticated {
                viewModel.startPolling()
            } else {
                viewModel.stopPolling()
            }
        }
        .onChange(of: spotify.authError) { _, error in
            viewModel.errorMessage = error
        }
    }

    @ViewBuilder
    private var playerView: some View {
        if let track = viewModel.currentTrack {
            GeometryReader { geometry in
                VStack(spacing: Layout.cardSpacing) {
                    TrackCardView(
                        track: track,
                        genres: viewModel.genres,
                        isLoadingGenres: viewModel.isLoadingGenres
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .measureHeight(into: $trackCardHeight)
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
                        .measureHeight(into: $descriptionCardHeight)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                viewModel.isDescriptionExpanded = true
                            }
                        }
                    }
                }
                .padding(.top, Layout.topPadding)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, Layout.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .gesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onEnded { value in
                            withAnimation(.easeInOut(duration: 0.4)) {
                                viewModel.isDescriptionExpanded = value.translation.height < 0
                            }
                        }
                )
                .offset(y: viewModel.isDescriptionExpanded
                    ? min(0, geometry.size.height
                        - Layout.topPadding
                        - trackCardHeight
                        - Layout.cardSpacing
                        - descriptionCardHeight
                        - Layout.bottomPadding)
                    : 0)
                .overlay(alignment: .topTrailing) {
                    // Load-bearing, intentionally hidden: `measureHeight` only keeps
                    // trackCardHeight/descriptionCardHeight up to date while a *rendered*
                    // view consumes them. Without this reader the expand offset above
                    // stays at 0 and the cards won't toggle until the next track reloads.
                    Text("\(Int(trackCardHeight)) \(Int(descriptionCardHeight)) \(Int(geometry.size.height))")
                        .hidden()
                }
            }
        } else {
            idleView
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

private extension View {
    /// Reports this view's height into `binding`, firing on the initial layout
    /// (via `onAppear`) as well as on later size changes.
    func measureHeight(into binding: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { binding.wrappedValue = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        binding.wrappedValue = newHeight
                    }
            }
        )
    }
}
