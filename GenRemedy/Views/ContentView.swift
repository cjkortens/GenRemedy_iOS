import SwiftUI

struct ContentView: View {
    @Environment(SpotifyRepository.self) var spotify
    @State private var viewModel = PlayerViewModel()

    // Scroll anchors for the two cards, used to snap the stack between the
    // track card (top) and the genre description (bottom) on tap.
    private enum Anchor {
        case track, description
    }

    private enum Layout {
        static let cardSpacing: CGFloat = 16
        static let topPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
        static let snap = Animation.easeInOut(duration: 0.4)
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Layout.cardSpacing) {
                        TrackCardView(
                            track: track,
                            genres: viewModel.genres,
                            isLoadingGenres: viewModel.isLoadingGenres
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .id(Anchor.track)
                        .onTapGesture {
                            withAnimation(Layout.snap) {
                                proxy.scrollTo(Anchor.track, anchor: .top)
                            }
                        }

                        if let primaryGenre = viewModel.genres.first {
                            GenreDescriptionCardView(
                                primaryGenre: primaryGenre,
                                description: viewModel.genreDescription,
                                isLoading: viewModel.isLoadingDescription
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .id(Anchor.description)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .onTapGesture {
                                withAnimation(Layout.snap) {
                                    proxy.scrollTo(Anchor.description, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .padding(.top, Layout.topPadding)
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, Layout.bottomPadding)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                // A new track resets focus to the top (track) card.
                .onChange(of: viewModel.currentTrack?.id) {
                    withAnimation(Layout.snap) {
                        proxy.scrollTo(Anchor.track, anchor: .top)
                    }
                }
            }
        } else {
            idleView
        }
    }

    private var loginView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Brand logo with a soft purple glow
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .shadow(color: Color.brandPurple.opacity(0.45), radius: 28, x: 0, y: 12)

            VStack(spacing: 14) {
                Text("GenRemedy")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .kerning(0.5)

                Capsule()
                    .fill(Color.brandPurple)
                    .frame(width: 44, height: 4)

                Text("Know your Sound")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }

            // Two trailing spacers to one leading: lifts the logo + title into
            // the upper third so the screen isn't bottom-heavy under the button.
            Spacer()
            Spacer()

            Button {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first
                else { return }
                spotify.startOAuth(presentationAnchor: window)
            } label: {
                Text("Connect with Spotify")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.brandPurpleLight, Color.brandPurpleDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.brandPurple.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#281A2B"), Color(hex: "#1A1A1A")],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.brandPurpleLight)
                .shadow(color: Color.brandPurple.opacity(0.5), radius: 24, x: 0, y: 8)

            VStack(spacing: 14) {
                Text("Nothing playing")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .kerning(0.5)

                Capsule()
                    .fill(Color.brandPurple)
                    .frame(width: 44, height: 4)

                Text("Play a track in Spotify to get started")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#281A2B"), Color(hex: "#1A1A1A")],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
    }
}
