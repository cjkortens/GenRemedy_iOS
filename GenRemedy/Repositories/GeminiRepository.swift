import Foundation

struct GeminiRepository {
    private let apiKey: String
    private let primaryModel = "gemini-3.5-flash"
    private let backupModel = "gemini-3.1-flash-lite-preview"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    init() {
        apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }

    func classifyGenres(trackName: String, artistName: String) async throws -> [String] {
        let systemInstruction = """
            You are a master musicologist and music history expert. Your sole task is to analyze the musical DNA of a given song and provide its top 3 most precise genres or subgenres.

            For every track provided, mentally evaluate its core sonic characteristics across all musical traditions:
            1. Instrumentation & Timbre: Identify primary sound sources, whether they are acoustic (e.g., brass, upright bass, piano), electric (e.g., high-gain distorted guitars, analog synths), or digital/synthetic (e.g., 808 sub-bass, 8-bit chiptune plucks, side-chained supersaws).
            2. Rhythmic Foundation & Tempo: Analyze the drum architecture and groove pattern (e.g., syncopated hip-hop boom-bap, rapid metal double-bass, swing-time jazz, 4x4 electronic house pulse, or driving rock backbeat).
            3. Vocal Style & Processing: Evaluate how the vocal is presented (e.g., raw and acoustic, auto-tuned melodic rap, multi-layered pop harmony, screaming/growling, or rhythmic patois).
            4. Cultural & Era Context: Factor in the artist's historical catalog and label alignment to differentiate between eras (e.g., 90s grunge vs. modern indie rock, classic east-coast rap vs. modern trap).

            Avoid vague, overarching classifications. Do not return umbrella terms like "Electronic", "Pop", "Rock", "Hip-Hop", or "Jazz" unless a track truly cannot be broken down into a definitive, recognized subgenre (e.g., prefer "Synthpop", "Boom-Bap", "Pop Punk", "Hard Bop", or "Slap House").
            """
        
        let prompt = "Song: \"\(trackName)\"\nArtist: \"\(artistName)\""
        
        // Define the strict JSON schema forcing an array of strings
        let jsonSchema: [String: Any] = [
            "type": "ARRAY",
            "description": "Exactly 3 of the most precise music subgenres for the track.",
            "items": [
                "type": "STRING"
            ]
        ]
        
        // Configuration block to enforce JSON mode and schema constraint
        let generationConfig: [String: Any] = [
            "temperature": 0.1, // Drastically lowers randomness for strict classification
            "responseMimeType": "application/json",
            "responseSchema": jsonSchema
        ]
        
        return try await fetchGenresAdvanced(
            prompt: prompt,
            systemInstruction: systemInstruction,
            config: generationConfig,
            model: primaryModel
        )
    }

    func describeGenre(_ genre: String) async throws -> String {
        let prompt = """
            Write a 4 to 5 sentence description of the "\(genre)" music genre. \
            Cover its origins, key characteristics, typical sounds or production style, \
            and the feeling or atmosphere it evokes. \
            Write in a clear, engaging style suitable for a music app. \
            Do not use bullet points, headers, or any formatting — just plain flowing sentences. \
            The entire response must be under 600 characters.
            """
        return try await fetchText(prompt: prompt, model: primaryModel)
    }

    // New advanced fetch helper specifically handling system instructions and schemas
    private func fetchGenresAdvanced(prompt: String, systemInstruction: String, config: [String: Any], model: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "systemInstruction": ["parts": [["text": systemInstruction]]],
            "generationConfig": config
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        print("[Gemini Advanced] model=\(model) status=\(http?.statusCode ?? -1)")

        if http?.statusCode == 503 && model == primaryModel {
            return try await fetchGenresAdvanced(prompt: prompt, systemInstruction: systemInstruction, config: config, model: backupModel)
        }

        guard let text = try? JSONDecoder().decode(GeminiResponse.self, from: data).candidates.first?.content.parts.first?.text,
              let genreData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let genres = try? JSONDecoder().decode([String].self, from: genreData),
              genres.count == 3
        else {
            if model == primaryModel {
                return try await fetchGenresAdvanced(prompt: prompt, systemInstruction: systemInstruction, config: config, model: backupModel)
            }
            throw GeminiError.parseError
        }
        return genres
    }

    // Retained for your standard describeGenre call
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
        print("[Gemini] model=\(model) status=\(http?.statusCode ?? -1)")

        if http?.statusCode == 503 && model == primaryModel {
            return try await fetchText(prompt: prompt, model: backupModel)
        }

        guard let text = try? JSONDecoder().decode(GeminiResponse.self, from: data).candidates.first?.content.parts.first?.text
        else { throw GeminiError.parseError }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GeminiError: Error {
    case invalidURL
    case parseError
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiContent: Decodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Decodable {
    let text: String
}
