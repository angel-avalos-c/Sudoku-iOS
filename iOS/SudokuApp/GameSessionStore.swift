import Foundation
import SudokuCore

/// Platform storage for a durable game snapshot.
///
/// The app depends on this protocol instead of a storage framework so the
/// Sudoku core remains independent of iOS persistence details.
@MainActor
protocol GameSessionPersisting: AnyObject {
    func load() -> GameSessionSnapshot?
    func save(_ snapshot: GameSessionSnapshot)
    func remove()
}

/// A local-only UserDefaults implementation for the active game.
final class UserDefaultsGameSessionStore: GameSessionPersisting {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "com.example.SudokuApp.gameSession") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> GameSessionSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(GameSessionSnapshot.self, from: data)
        } catch {
            // A bad payload must not keep preventing a playable fresh launch.
            remove()
            return nil
        }
    }

    func save(_ snapshot: GameSessionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func remove() {
        defaults.removeObject(forKey: key)
    }
}
