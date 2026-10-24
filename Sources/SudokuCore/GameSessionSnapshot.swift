/// Errors returned when persisted game-session data cannot be safely restored.
public enum GameSessionSnapshotError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case modifiedGiven(row: Int, column: Int)
    case conflictingValue(row: Int, column: Int)
    case inconsistentStatus
    case invalidNotes
    case invalidHintsUsed
}

/// The versioned, platform-independent durable state of a game session.
///
/// This is deliberately a data transfer object: platform adapters choose how
/// to encode and store it, while the core validates every value on restore.
public struct GameSessionSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 3

    public let version: Int
    public let givens: [[Int]]
    public let solution: [[Int]]
    public let values: [[Int]]
    public let difficulty: SudokuDifficulty?
    public let status: GameStatus
    /// Sorted candidate values for each board coordinate.
    public let notes: [[[Int]]]
    /// The number of hints applied during this game.
    public let hintsUsed: Int

    public init(
        version: Int = GameSessionSnapshot.currentVersion,
        givens: [[Int]],
        solution: [[Int]],
        values: [[Int]],
        difficulty: SudokuDifficulty?,
        status: GameStatus,
        notes: [[[Int]]]? = nil,
        hintsUsed: Int = 0
    ) {
        self.version = version
        self.givens = givens
        self.solution = solution
        self.values = values
        self.difficulty = difficulty
        self.status = status
        self.notes = notes ?? Self.emptyNotes
        self.hintsUsed = hintsUsed
    }

    private enum CodingKeys: String, CodingKey {
        case version, givens, solution, values, difficulty, status, notes, hintsUsed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        givens = try container.decode([[Int]].self, forKey: .givens)
        solution = try container.decode([[Int]].self, forKey: .solution)
        values = try container.decode([[Int]].self, forKey: .values)
        difficulty = try container.decodeIfPresent(SudokuDifficulty.self, forKey: .difficulty)
        status = try container.decode(GameStatus.self, forKey: .status)
        if version == 1 {
            notes = try container.decodeIfPresent([[[Int]]].self, forKey: .notes) ?? Self.emptyNotes
        } else {
            notes = try container.decode([[[Int]]].self, forKey: .notes)
        }
        if version <= 2 {
            hintsUsed = try container.decodeIfPresent(Int.self, forKey: .hintsUsed) ?? 0
        } else {
            hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
        }
    }

    private static let emptyNotes = Array(
        repeating: Array(repeating: [Int](), count: SudokuRules.gridSize),
        count: SudokuRules.gridSize
    )
}
