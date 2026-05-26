import Foundation
import FirebaseDatabase

@MainActor
class GenreDescriptionRepository {
    static let shared = GenreDescriptionRepository()
    private let db = Database.database().reference()

    private func genreKey(_ genre: String) -> String {
        genre.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    func fetchDescription(genre: String) async -> String? {
        let key = genreKey(genre)
        return await withCheckedContinuation { continuation in
            db.child("global_library/genres/\(key)/description").observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot.value as? String)
            }
        }
    }

    func saveDescription(genre: String, description: String) {
        let key = genreKey(genre)
        let entry: [String: Any] = [
            "description": description,
            "lastUpdated": Int(Date().timeIntervalSince1970 * 1000),
        ]
        db.child("global_library/genres/\(key)").setValue(entry)
    }
}
