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
}

/// State and interactions for one deterministic Sudoku game.
///
/// Moves use zero-based coordinates. Conflicting, out-of-range, and fixed-cell
/// moves throw `SudokuBoardError`, do not change the board, and are retained in
/// `lastMoveError` for UI feedback. A successful move clears that feedback.
/// Attempts to edit a completed game throw `GameSessionError.gameAlreadyCompleted`
/// and retain the existing `lastMoveError` unchanged.
public struct GameSession: Equatable, Sendable {
    public let puzzle: Puzzle
    public private(set) var board: Board
    public private(set) var selectedCell: CellCoordinate?
    public private(set) var status: GameStatus
    public private(set) var lastMoveError: SudokuBoardError?

    /// Starts a session from a validated, reproducible puzzle.
    public init(puzzle: Puzzle = PuzzleCatalog.starter) throws {
        self.puzzle = puzzle
        board = try puzzle.makeBoard()
        selectedCell = nil
        status = board.isSolved ? .completed : .inProgress
        lastMoveError = nil
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

    private mutating func updateStatus() {
        status = board.isSolved ? .completed : .inProgress
    }
}
