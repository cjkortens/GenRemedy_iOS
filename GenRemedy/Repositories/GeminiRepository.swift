import Foundation

struct GeminiRepository {
    private let apiKey: String
    private let primaryModel = "gemini-3-flash-preview"
    private let backupModel = "gemini-3.1-flash-lite-preview"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    init() {
        apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }

    func classifyGenres(trackName: String, artistName: String) async throws -> [String] {
        let prompt = """
            You are a music genre expert. Given the song and artist below, list exactly 3 music genres \
            that best describe this track (from most specific to most general). \
            Respond with ONLY a JSON array of 3 strings and nothing else. \
            Example: ["synthpop","electropop","pop"]

            Song: "\(trackName)"
            Artist: "\(artistName)"
            """
        return try await fetchGenres(prompt: prompt, model: primaryModel)
    }

    func describeGenre(_ genre: String) async throws -> String {
        let prompt = """
            Write exactly 2 sentences about the "\(genre)" music genre. \
            Cover its defining sound and the feeling it evokes. \
            Be concise — the entire response must be under 200 characters. \
            No bullet points, headers, or extra formatting.
            """
        return try await fetchText(prompt: prompt, model: primaryModel)
    }

    private func fetchGenres(prompt: String, model: String) async throws -> [String] {
        let text = try await fetchText(prompt: prompt, model: model)
        guard let startIdx = text.firstIndex(of: "["),
              let endIdx = text.lastIndex(of: "]"),
              startIdx <= endIdx
        else {
            if model == primaryModel {
                return try await fetchGenres(prompt: prompt, model: backupModel)
            }
            throw GeminiError.parseError
        }
        let jsonSlice = String(text[startIdx...endIdx])
        guard let data = jsonSlice.data(using: .utf8),
              let genres = try? JSONDecoder().decode([String].self, from: data),
              genres.count == 3
        else {
            if model == primaryModel {
                return try await fetchGenres(prompt: prompt, model: backupModel)
            }
            throw GeminiError.parseError
        }
        return genres
    }

    private func fetchText(prompt: String, model: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse

        if http?.statusCode == 503 && model == primaryModel {
            return try await fetchText(prompt: prompt, model: backupModel)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw GeminiError.parseError }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GeminiError: Error {
    case invalidURL
    case parseError
}
