import SwiftUI
import FirebaseCore

@main
struct GenRemedyApp: App {
    @StateObject private var spotify = SpotifyRepository.shared

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        // Prevent iOS 26's glass chrome from adding automatic scroll content insets
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotify)
                .onOpenURL { url in
                    Task { @MainActor in
                        await spotify.handleCallback(url: url)
                    }
                }
        }
    }
}
