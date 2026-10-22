/// Errors returned when creating a Sudoku puzzle and solution pair.
public enum PuzzleError: Error, Equatable, Sendable {
    case invalidSolution
    case conflictingGiven(row: Int, column: Int)
    case givenDoesNotMatchSolution(row: Int, column: Int)
}

/// A validated, reproducible Sudoku puzzle paired with its solution.
///
/// `givens` contains the starting board values. Nonzero values are immutable
/// givens; `0` denotes an editable empty cell. Coordinates are zero-based.
public struct Puzzle: Equatable, Sendable {
    public let givens: [[Int]]
    public let solution: [[Int]]

    /// Creates a puzzle whose givens are compatible with a complete solution.
    ///
    /// - Throws: A `SudokuBoardError` for invalid matrix dimensions or values;
    ///   `PuzzleError.invalidSolution` when `solution` is not solved;
    ///   `PuzzleError.conflictingGiven` for conflicting starting values; or
    ///   `PuzzleError.givenDoesNotMatchSolution` when a given differs from the
    ///   solution at the same coordinate.
    public init(givens: [[Int]], solution: [[Int]]) throws {
        try SudokuRules.validate(values: givens)
        try SudokuRules.validate(values: solution)

        guard try SudokuRules.isSolved(solution) else {
            throw PuzzleError.invalidSolution
        }

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize {
                if try SudokuRules.hasConflict(in: givens, row: row, column: column) {
                    throw PuzzleError.conflictingGiven(row: row, column: column)
                }
                if givens[row][column] != 0, givens[row][column] != solution[row][column] {
                    throw PuzzleError.givenDoesNotMatchSolution(row: row, column: column)
                }
            }
        }

        self.givens = givens
        self.solution = solution
    }

    /// Creates a fresh board with each nonzero given marked immutable.
    public func makeBoard() throws -> Board {
        try Board(values: givens)
    }
}
