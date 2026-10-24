/// A zero-based coordinate on a standard Sudoku board.
public struct CellCoordinate: Equatable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

/// The current state of a Sudoku game session.
public enum GameStatus: String, Codable, Equatable, Sendable {
    case inProgress
    case completed
}

/// Errors returned by game-session state transitions.
public enum GameSessionError: Error, Equatable, Sendable {
    /// A completed session is immutable until it is reset.
    case gameAlreadyCompleted
    /// A distinct dynamically generated puzzle could not be created in time.
    case unableToGenerateNewPuzzle(SudokuDifficulty, attempts: Int)
    /// Candidate notes must be values from 1 through 9.
    case invalidNoteValue(Int)
    /// Notes cannot coexist with an entered value in the same editable cell.
    case cannotAddNoteToFilledCell(row: Int, column: Int)
}

/// A deterministic value applied by ``GameSession/applyHint()``.
public struct GameHint: Equatable, Sendable {
    public let coordinate: CellCoordinate
    public let value: Int

    public init(coordinate: CellCoordinate, value: Int) {
        self.coordinate = coordinate
        self.value = value
    }
}

/// State and interactions for one deterministic Sudoku game.
///
/// Moves use zero-based coordinates. Conflicting, out-of-range, and fixed-cell
/// moves throw `SudokuBoardError`, do not change the board, and are retained in
/// `lastMoveError` for UI feedback. A successful move clears that feedback.
/// Attempts to edit a completed game throw `GameSessionError.gameAlreadyCompleted`
/// and retain the existing `lastMoveError` unchanged.
public struct GameSession: Equatable, Sendable {
    public private(set) var puzzle: Puzzle
    /// The difficulty of a dynamically generated puzzle, if applicable.
    public private(set) var difficulty: SudokuDifficulty?
    public private(set) var board: Board
    public private(set) var selectedCell: CellCoordinate?
    public private(set) var status: GameStatus
    public private(set) var lastMoveError: SudokuBoardError?
    /// Candidate notes for editable, empty cells. Each set contains values in 1...9.
    public private(set) var notes: [[Set<Int>]]
    /// The number of hints applied during this game.
    public private(set) var hintsUsed: Int

    private var puzzleGenerator: SudokuPuzzleGenerator?

    /// Starts a session from a validated, reproducible puzzle.
    public init(puzzle: Puzzle = PuzzleCatalog.starter) throws {
        self.puzzle = puzzle
        difficulty = nil
        board = try puzzle.makeBoard()
        selectedCell = nil
        status = board.isSolved ? .completed : .inProgress
        lastMoveError = nil
        notes = Self.emptyNotes
        hintsUsed = 0
        puzzleGenerator = nil
    }

    /// Starts a session from a newly generated puzzle at the requested difficulty.
    public init(difficulty: SudokuDifficulty) throws {
        var generator = SudokuPuzzleGenerator()
        let puzzle = try generator.generate(difficulty: difficulty)
        try self.init(puzzle: puzzle)
        self.difficulty = difficulty
        puzzleGenerator = generator
    }

    /// Starts a deterministic generated session for reproducible tests.
    public init(difficulty: SudokuDifficulty, seed: UInt64) throws {
        var generator = SudokuPuzzleGenerator(seed: seed)
        let puzzle = try generator.generate(difficulty: difficulty)
        try self.init(puzzle: puzzle)
        self.difficulty = difficulty
        puzzleGenerator = generator
    }

    /// Restores a validated, versioned snapshot created by ``snapshot``.
    ///
    /// Invalid or unsupported snapshots are rejected rather than allowing
    /// persisted data to bypass the game's normal board invariants.
    public init(snapshot: GameSessionSnapshot) throws {
        guard (1...GameSessionSnapshot.currentVersion).contains(snapshot.version) else {
            throw GameSessionSnapshotError.unsupportedVersion(snapshot.version)
        }

        let puzzle = try Puzzle(givens: snapshot.givens, solution: snapshot.solution)
        try SudokuRules.validate(values: snapshot.values)

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize {
                if puzzle.givens[row][column] != 0,
                   snapshot.values[row][column] != puzzle.givens[row][column] {
                    throw GameSessionSnapshotError.modifiedGiven(row: row, column: column)
                }
                if try SudokuRules.hasConflict(in: snapshot.values, row: row, column: column) {
                    throw GameSessionSnapshotError.conflictingValue(row: row, column: column)
                }
            }
        }

        let board = try Board(
            values: snapshot.values,
            givens: puzzle.givens.map { $0.map { $0 != 0 } }
        )
        let restoredStatus: GameStatus = board.isSolved ? .completed : .inProgress
        guard snapshot.status == restoredStatus else {
            throw GameSessionSnapshotError.inconsistentStatus
        }
        let notes = try Self.validatedNotes(snapshot.notes, board: board)
        guard snapshot.hintsUsed >= 0 else {
            throw GameSessionSnapshotError.invalidHintsUsed
        }

        self.puzzle = puzzle
        difficulty = snapshot.difficulty
        self.board = board
        selectedCell = nil
        status = restoredStatus
        lastMoveError = nil
        self.notes = notes
        hintsUsed = snapshot.hintsUsed
        puzzleGenerator = nil
    }

    /// Captures the durable state required to resume this game later.
    /// Selection and transient move feedback are intentionally excluded.
    public func snapshot() -> GameSessionSnapshot {
        GameSessionSnapshot(
            version: GameSessionSnapshot.currentVersion,
            givens: puzzle.givens,
            solution: puzzle.solution,
            values: board.values,
            difficulty: difficulty,
            status: status,
            notes: notes.map { $0.map { $0.sorted() } },
            hintsUsed: hintsUsed
        )
    }

    /// Selects any in-bounds cell. Both given and editable cells may be
    /// selected so a UI can inspect either kind of cell.
    public mutating func selectCell(row: Int, column: Int) throws {
        _ = try board.readCell(row: row, column: column)
        selectedCell = CellCoordinate(row: row, column: column)
    }

    /// Clears the current selection without changing the board.
    public mutating func clearSelection() {
        selectedCell = nil
    }

    /// Applies an entry to an editable cell.
    ///
    /// - Throws: The typed `SudokuBoardError` from `Board` for rejected moves.
    ///   Rejected active-game moves leave the board unchanged and set
    ///   `lastMoveError`. Completed-game edits throw
    ///   `GameSessionError.gameAlreadyCompleted` without changing feedback.
    public mutating func setValue(_ value: Int, row: Int, column: Int) throws {
        guard status != .completed else {
            throw GameSessionError.gameAlreadyCompleted
        }

        do {
            try board.setValue(value, row: row, column: column)
            notes[row][column].removeAll()
            lastMoveError = nil
            updateStatus()
        } catch let error as SudokuBoardError {
            lastMoveError = error
            throw error
        }
    }

    /// Clears an editable cell.
    ///
    /// - Throws: The typed `SudokuBoardError` from `Board` for rejected active
    ///   game moves, or `GameSessionError.gameAlreadyCompleted` without
    ///   changing feedback after completion.
    public mutating func clearCell(row: Int, column: Int) throws {
        try setValue(0, row: row, column: column)
    }

    /// Toggles one candidate note on an editable, empty cell.
    ///
    /// Notes are cleared when a value is successfully committed or cleared.
    public mutating func toggleNote(_ value: Int, row: Int, column: Int) throws {
        guard status != .completed else {
            throw GameSessionError.gameAlreadyCompleted
        }
        guard (1...SudokuRules.gridSize).contains(value) else {
            throw GameSessionError.invalidNoteValue(value)
        }
        let cell = try board.readCell(row: row, column: column)
        guard cell.isEditable else {
            throw SudokuBoardError.cannotModifyGiven(row: row, column: column)
        }
        guard cell.value == 0 else {
            throw GameSessionError.cannotAddNoteToFilledCell(row: row, column: column)
        }

        if notes[row][column].contains(value) {
            notes[row][column].remove(value)
        } else {
            notes[row][column].insert(value)
        }
        lastMoveError = nil
    }

    /// Applies the first row-major solution value that is currently legal.
    ///
    /// A hint is deterministic for identical game state. It does not affect
    /// score or statistics. `nil` means no solution value can currently be
    /// applied without conflicting with the board.
    @discardableResult
    public mutating func applyHint() throws -> GameHint? {
        guard status != .completed else {
            throw GameSessionError.gameAlreadyCompleted
        }

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize {
                let cell = try board.readCell(row: row, column: column)
                guard cell.isEditable, cell.value == 0 else { continue }

                let value = puzzle.solution[row][column]
                guard try !board.wouldConflict(value: value, row: row, column: column) else {
                    continue
                }

                try setValue(value, row: row, column: column)
                hintsUsed += 1
                return GameHint(
                    coordinate: CellCoordinate(row: row, column: column),
                    value: value
                )
            }
        }
        return nil
    }

    /// Restores the original givens, clears selection and feedback, and marks
    /// the session in progress unless the original puzzle is already solved.
    public mutating func reset() throws {
        board = try puzzle.makeBoard()
        selectedCell = nil
        lastMoveError = nil
        notes = Self.emptyNotes
        hintsUsed = 0
        updateStatus()
    }

    /// Replaces the current puzzle with a dynamically generated one.
    ///
    /// The session retains its generator state, so a seeded session produces a
    /// reproducible sequence. The current puzzle is never returned again by
    /// this transition; failure to find a distinct replacement is explicit.
    public mutating func newGame(difficulty: SudokuDifficulty) throws {
        try newGame(difficulty: difficulty, maximumGenerationAttempts: 12)
    }

    mutating func newGame(
        difficulty: SudokuDifficulty,
        maximumGenerationAttempts: Int
    ) throws {
        var generator = puzzleGenerator ?? SudokuPuzzleGenerator()
        let nextPuzzle = try generateDistinctPuzzle(
            difficulty: difficulty,
            using: &generator,
            maximumGenerationAttempts: maximumGenerationAttempts
        )
        let nextBoard = try nextPuzzle.makeBoard()

        puzzle = nextPuzzle
        self.difficulty = difficulty
        board = nextBoard
        selectedCell = nil
        lastMoveError = nil
        notes = Self.emptyNotes
        hintsUsed = 0
        puzzleGenerator = generator
        updateStatus()
    }

    private func generateDistinctPuzzle(
        difficulty: SudokuDifficulty,
        using generator: inout SudokuPuzzleGenerator,
        maximumGenerationAttempts: Int
    ) throws -> Puzzle {
        let maximumDistinctPuzzleAttempts = 3
        for _ in 0..<maximumDistinctPuzzleAttempts {
            do {
                let candidate = try generator.generate(
                    difficulty: difficulty,
                    maximumGenerationAttempts: maximumGenerationAttempts
                )
                if candidate.givens != puzzle.givens {
                    return candidate
                }
            } catch let error as SudokuPuzzleGeneratorError {
                if case .unableToGenerateDifficulty = error {
                    continue
                }
                throw error
            }
        }

        throw GameSessionError.unableToGenerateNewPuzzle(
            difficulty,
            attempts: maximumDistinctPuzzleAttempts
        )
    }

    private mutating func updateStatus() {
        status = board.isSolved ? .completed : .inProgress
    }

    private static let emptyNotes = Array(
        repeating: Array(repeating: Set<Int>(), count: SudokuRules.gridSize),
        count: SudokuRules.gridSize
    )

    private static func validatedNotes(_ snapshotNotes: [[[Int]]], board: Board) throws -> [[Set<Int>]] {
        guard snapshotNotes.count == SudokuRules.gridSize,
              snapshotNotes.allSatisfy({ $0.count == SudokuRules.gridSize }) else {
            throw GameSessionSnapshotError.invalidNotes
        }

        return try snapshotNotes.enumerated().map { row, rowNotes in
            try rowNotes.enumerated().map { column, candidates in
                let notes = Set(candidates)
                guard notes.count == candidates.count,
                      notes.allSatisfy({ (1...SudokuRules.gridSize).contains($0) }) else {
                    throw GameSessionSnapshotError.invalidNotes
                }
                let cell = try board.readCell(row: row, column: column)
                guard cell.isEditable ? cell.value == 0 || notes.isEmpty : notes.isEmpty else {
                    throw GameSessionSnapshotError.invalidNotes
                }
                return notes
            }
        }
    }
}
