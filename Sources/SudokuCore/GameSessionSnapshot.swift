/// Errors returned when persisted game-session data cannot be safely restored.
public enum GameSessionSnapshotError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case modifiedGiven(row: Int, column: Int)
    case conflictingValue(row: Int, column: Int)
    case inconsistentStatus
}

/// The versioned, platform-independent durable state of a game session.
///
/// This is deliberately a data transfer object: platform adapters choose how
/// to encode and store it, while the core validates every value on restore.
public struct GameSessionSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let givens: [[Int]]
    public let solution: [[Int]]
    public let values: [[Int]]
    public let difficulty: SudokuDifficulty?
    public let status: GameStatus

    public init(
        version: Int = GameSessionSnapshot.currentVersion,
        givens: [[Int]],
        solution: [[Int]],
        values: [[Int]],
        difficulty: SudokuDifficulty?,
        status: GameStatus
    ) {
        self.version = version
        self.givens = givens
        self.solution = solution
        self.values = values
        self.difficulty = difficulty
        self.status = status
    }
}
