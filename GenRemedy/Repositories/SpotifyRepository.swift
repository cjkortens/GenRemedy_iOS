import Foundation
import AuthenticationServices

@MainActor
class SpotifyRepository: NSObject, ObservableObject {
    static let shared = SpotifyRepository()

    private let clientId: String
    private let clientSecret: String
    private let redirectURI = "genremedy://callback"
    private let scope = "user-read-currently-playing"
    private let tokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"

    @Published var isAuthenticated = false
    private var accessToken: String?
    private var webAuthSession: ASWebAuthenticationSession?
    nonisolated(unsafe) private var storedAnchor: ASPresentationAnchor?

    override init() {
        let dict = Bundle.main.infoDictionary
        clientId = dict?["SPOTIFY_CLIENT_ID"] as? String ?? ""
        clientSecret = dict?["SPOTIFY_CLIENT_SECRET"] as? String ?? ""
        super.init()
        if let token = KeychainHelper.read(key: tokenKey) {
            accessToken = token
            isAuthenticated = true
        }
    }

    func startOAuth(presentationAnchor: ASPresentationAnchor) {
        storedAnchor = presentationAnchor
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scope),
        ]
        guard let url = components.url else { return }

        webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "genremedy"
        ) { [weak self] callbackURL, error in
            guard let self, let callbackURL, error == nil else { return }
            Task { await self.handleCallback(url: callbackURL) }
        }
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }

    func handleCallback(url: URL) async {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { return }
        await exchangeCode(code)
    }

    private func exchangeCode(_ code: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        let credentials = "\(clientId):\(clientSecret)"
        guard let credData = credentials.data(using: .utf8) else { return }
        let b64 = credData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(b64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        let body = "grant_type=authorization_code&code=\(encodedCode)&redirect_uri=\(encodedRedirect)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(SpotifyUserTokenResponse.self, from: data)
            accessToken = tokenResponse.accessToken
            KeychainHelper.save(key: tokenKey, value: tokenResponse.accessToken)
            if let refresh = tokenResponse.refreshToken {
                KeychainHelper.save(key: refreshTokenKey, value: refresh)
            }
            isAuthenticated = true
        } catch {
            print("Token exchange error: \(error)")
        }
    }

    func fetchCurrentlyPlaying() async throws -> CurrentlyPlayingResponse? {
        guard let token = accessToken else { return nil }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse

        if http?.statusCode == 204 { return nil }
        if http?.statusCode == 401 {
            isAuthenticated = false
            accessToken = nil
            return nil
        }
        return try JSONDecoder().decode(CurrentlyPlayingResponse.self, from: data)
    }

    func signOut() {
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: refreshTokenKey)
        accessToken = nil
        isAuthenticated = false
    }
}

extension SpotifyRepository: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        storedAnchor!
    }
}

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
