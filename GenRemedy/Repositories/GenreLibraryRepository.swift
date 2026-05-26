import Foundation
import FirebaseDatabase

@MainActor
class GenreLibraryRepository {
    static let shared = GenreLibraryRepository()
    private let db = Database.database().reference()

    func fetchGenres(trackId: String) async -> [String]? {
        return await withCheckedContinuation { continuation in
            db.child("global_library/tracks/\(trackId)").observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists(),
                      let dict = snapshot.value as? [String: Any],
                      let g1 = dict["genre1"] as? String,
                      let g2 = dict["genre2"] as? String,
                      let g3 = dict["genre3"] as? String
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: [g1, g2, g3])
            }
        }
    }

    func saveGenres(trackId: String, genres: [String]) {
        guard genres.count == 3 else { return }
        let entry: [String: Any] = [
            "genre1": genres[0],
            "genre2": genres[1],
            "genre3": genres[2],
            "lastUpdated": Int(Date().timeIntervalSince1970 * 1000),
        ]
        db.child("global_library/tracks/\(trackId)").setValue(entry)
    }
}
