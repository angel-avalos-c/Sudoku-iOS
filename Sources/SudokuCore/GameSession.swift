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
public enum GameStatus: Equatable, Sendable {
    case inProgress
    case completed
}

/// Errors returned by game-session state transitions.
public enum GameSessionError: Error, Equatable, Sendable {
    /// A completed session is immutable until it is reset.
    case gameAlreadyCompleted
    /// A distinct dynamically generated puzzle could not be created in time.
    case unableToGenerateNewPuzzle(SudokuDifficulty, attempts: Int)
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

    private var puzzleGenerator: SudokuPuzzleGenerator?

    /// Starts a session from a validated, reproducible puzzle.
    public init(puzzle: Puzzle = PuzzleCatalog.starter) throws {
        self.puzzle = puzzle
        difficulty = nil
        board = try puzzle.makeBoard()
        selectedCell = nil
        status = board.isSolved ? .completed : .inProgress
        lastMoveError = nil
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

    /// Restores the original givens, clears selection and feedback, and marks
    /// the session in progress unless the original puzzle is already solved.
    public mutating func reset() throws {
        board = try puzzle.makeBoard()
        selectedCell = nil
        lastMoveError = nil
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
}
