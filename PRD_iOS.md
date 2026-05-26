# GenRemedy — iOS App Store PRD

## Overview

GenRemedy is a music companion app that connects to Spotify and uses Google Gemini AI to identify and describe the genre of whatever track you're currently playing. This document describes requirements for porting the existing Android app to a native iOS application suitable for App Store distribution.

---

## Reference: Android App Architecture

The Android app (`/app/src/main/java/com/example/musicapp/`) has these layers:

| Android Layer | Role |
|---|---|
| `MainActivity.kt` + Compose UI | Single screen: track card + genre description card |
| `SpotifyRepository.kt` | Spotify OAuth 2.0 + Web API calls via Ktor |
| `GeminiRepository.kt` | Gemini Flash API calls for genre classification and descriptions |
| `GenreLibraryRepository.kt` | Firebase Realtime Database read/write for track→genre cache |
| `GenreDescriptionRepository.kt` | Firebase Realtime Database read/write for genre→description cache |
| `SpotifyModels.kt` | Data models (track, album, artist, genre entry) |

**Credentials** are stored in `local.properties` and injected at build time as `BuildConfig` fields:
- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`
- `GEMINI_API_KEY`

**OAuth redirect URI (Android):** `com.example.musicapp://callback`

---

## iOS Tech Stack

| Concern | Android | iOS |
|---|---|---|
| Language | Kotlin | Swift |
| UI framework | Jetpack Compose | SwiftUI |
| HTTP client | Ktor (Android engine) | `URLSession` (async/await) |
| JSON parsing | kotlinx.serialization | `Codable` |
| Image loading | Coil | `AsyncImage` (SwiftUI built-in) |
| Firebase | Firebase Android SDK | Firebase iOS SDK (via SPM) |
| OAuth browser | `Intent.ACTION_VIEW` + deep link | `ASWebAuthenticationSession` |
| Build / dependency mgr | Gradle + AGP | Xcode + Swift Package Manager |
| Credentials | `local.properties` + BuildConfig | `Secrets.xcconfig` (gitignored) |
| App ID / bundle | `com.example.musicapp` | `com.example.genremedy` (or your own reverse-DNS) |

---

## Core Features (parity with Android)

### 1. Spotify OAuth 2.0 Login
- Use `ASWebAuthenticationSession` to open the Spotify authorization URL in an in-app browser.
- Scope required: `user-read-currently-playing`
- On redirect, parse the authorization `code` from the callback URL.
- Exchange the code for an access token + refresh token via `POST /api/token` (Authorization Code Flow).
- Store tokens in Keychain (not UserDefaults).
- **Redirect URI for iOS:** `genremedy://callback` — register this in the Spotify Developer Dashboard and as a URL scheme in `Info.plist`.

### 2. Currently Playing Track Display
Poll `GET https://api.spotify.com/v1/me/player/currently-playing` every **5 seconds**.

Display per track:
- Album art (280×280pt, rounded corners) — load from the first image in `album.images`
- Track name (bold headline)
- Artist name(s) (comma-joined)
- Release year (first 4 characters of `album.release_date`)
- Up to 3 genre chips (pill-shaped tags, most specific → most general)

### 3. Genre Classification via Gemini AI
On each new track (detected by `id` change):
1. Check Firebase cache at `global_library/tracks/{trackId}` — if hit, use cached genres.
2. On cache miss, call Gemini with the prompt: *"list exactly 3 music genres that best describe this track… respond with ONLY a JSON array of 3 strings"*.
3. Parse the JSON array; save result to Firebase.
4. Display genres as pill chips.

**Gemini models** (try in order, fall back on 503):
- Primary: `gemini-3-flash-preview`
- Backup: `gemini-3.1-flash-lite-preview`

**Endpoint:** `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEMINI_API_KEY}`

### 4. Genre Description via Gemini AI
When the primary genre changes:
1. Check Firebase cache at `global_library/genres/{genre_key}/description`.
2. On cache miss, call Gemini: *"Write a 4–5 sentence description of the '{genre}' music genre… plain flowing sentences, no formatting."*
3. Save to Firebase and display in the description card.

### 5. Firebase Caching (shared with Android)
The iOS app reads from and writes to the **same Firebase Realtime Database** as the Android app, so genre lookups are shared globally across users on both platforms.

Database structure:
```
global_library/
  tracks/
    {trackId}/
      genre1: String
      genre2: String
      genre3: String
      lastUpdated: Long (ms since epoch)
  genres/
    {genre_key}/        ← lowercase, spaces → underscores
      description: String
      lastUpdated: Long
```

---

## UI / UX Design

### Layout
Two-card vertical layout (matching Android):

1. **Track Card** (top)
   - Dark grey background, 20pt corner radius
   - Album art → track name → artist(s) → release year → genre chips
   - Tap → scroll to top (reveals track card fully)

2. **Genre Description Card** (below track card)
   - Slides in with fade when genres first load (400ms animation)
   - Header: capitalized primary genre name, in accent color
   - Body: full description text
   - Tap → scroll down to reveal description card fully

### Scroll Behavior
- Wrap both cards in a `ScrollView`, but **disable user-initiated scrolling** (pointer events pass through; only programmatic scroll via `ScrollViewReader.scrollTo` or `.offset` animation).
- On `isDescriptionExpanded = true` → animate scroll to bottom.
- On `isDescriptionExpanded = false` → animate scroll to top.

### Colors / Theme
- Background and card fill: dark grey (match Android's `AppDarkGrey` ≈ `#2A2A2A` — confirm exact hex from `Color.kt`)
- Genre chips: `primaryContainer` color with `onPrimaryContainer` text (Material You equivalent in SwiftUI: use a tinted surface)
- Primary accent: used for genre name header
- Overall: dark mode, no light mode required for v1

---

## Data Models (Swift `Codable` equivalents)

```swift
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
```

---

## Project Structure (recommended)

```
GenRemedy-iOS/
├── GenRemedy.xcodeproj
├── Secrets.xcconfig          ← gitignored; holds API keys
├── GenRemedy/
│   ├── App/
│   │   ├── GenRemedyApp.swift
│   │   └── Info.plist        ← URL scheme: genremedy
│   ├── Repositories/
│   │   ├── SpotifyRepository.swift
│   │   ├── GeminiRepository.swift
│   │   ├── GenreLibraryRepository.swift
│   │   └── GenreDescriptionRepository.swift
│   ├── Models/
│   │   └── SpotifyModels.swift
│   ├── Views/
│   │   ├── ContentView.swift          ← root; handles OAuth redirect
│   │   ├── TrackCardView.swift
│   │   └── GenreDescriptionCardView.swift
│   ├── ViewModels/
│   │   └── PlayerViewModel.swift      ← @MainActor ObservableObject; owns polling loop
│   └── Resources/
│       └── Assets.xcassets
├── GoogleService-Info.plist  ← Firebase config (gitignored or project-specific)
```

---

## Secrets / Credentials

Create `Secrets.xcconfig` in the project root (add to `.gitignore`):
```
SPOTIFY_CLIENT_ID = your_client_id_here
SPOTIFY_CLIENT_SECRET = your_client_secret_here
GEMINI_API_KEY = your_key_here
```

Reference in `Info.plist` and access at runtime via `Bundle.main.infoDictionary`.

---

## OAuth Deep Link Setup

In `Info.plist`, add a URL scheme so the app can receive the OAuth callback:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>genremedy</string>
    </array>
  </dict>
</array>
```

In the Spotify Developer Dashboard, add `genremedy://callback` as an allowed Redirect URI.

Handle the callback in `GenRemedyApp.swift` using `.onOpenURL { url in ... }`.

---

## Swift Package Manager Dependencies

| Package | Purpose |
|---|---|
| `firebase-ios-sdk` (Google) | Firebase Realtime Database |

Everything else (`URLSession`, `AsyncImage`, `ASWebAuthenticationSession`, `Codable`) is in the Swift standard library or Apple frameworks — no additional packages needed.

---

## App Store Requirements

- **Minimum iOS version:** iOS 16 (for SwiftUI `NavigationStack`, `async/await` availability)
- **Device support:** iPhone (portrait); iPad optional for v1
- **Privacy:** The app reads Spotify listening data. Add `NSUserTrackingUsageDescription` only if analytics are added. Include a privacy policy URL in App Store Connect.
- **App Store Connect:** Create a new app with bundle ID matching `CFBundleIdentifier` in Xcode.
- **Capabilities:** No special entitlements needed beyond standard networking.
- **Background refresh:** Not required for v1 — app only polls while foregrounded.

---

## Out of Scope for v1

- Token refresh (refresh_token flow) — user re-authenticates if token expires
- `AudioFeatures` endpoint (modeled but unused in Android)
- `getArtist` endpoint (modeled but unused in Android)
- Light mode support
- iPad-optimized layout
- Offline / no-network state handling beyond status text
- Push notifications
- Widgets / Lock Screen integration

---

## Open Questions

1. **Bundle ID:** Finalize the iOS bundle identifier before creating the Xcode project and App Store Connect listing.
2. **Firebase project:** Should the iOS app share the existing Firebase project (same Realtime Database, so genre cache is shared across platforms) or use a separate one?
3. **App name:** "GenRemedy" or a different display name for the App Store?
4. **Token persistence:** Should the access token be persisted in Keychain across app launches, or require re-login each time (simpler for v1)?
