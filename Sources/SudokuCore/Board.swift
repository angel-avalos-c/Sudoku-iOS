/// Errors returned by Sudoku board construction and moves.
public enum SudokuBoardError: Error, Equatable, Sendable {
    case invalidDimensions
    case invalidCellValue(Int)
    case emptyGivenCell
    case invalidCoordinate(row: Int, column: Int)
    case cannotModifyGiven(row: Int, column: Int)
    case conflictingMove(value: Int, row: Int, column: Int)
}

/// A mutable, deterministic representation of a standard Sudoku board.
///
/// Rows and columns use zero-based coordinates in `0...8`. Cell values use
/// `0...9`, with `0` meaning empty. Moves that are invalid or target a given
/// throw a `SudokuBoardError` and leave the board unchanged.
public struct Board: Equatable, Sendable {
    public private(set) var cells: [[Cell]]

    /// Creates a board from a 9 by 9 value matrix.
    ///
    /// When `givens` is omitted, all nonzero values are treated as givens.
    /// Supplying `givens` permits an editable cell to begin with a nonzero
    /// value. Both matrices must have exactly nine rows and nine columns.
    public init(values: [[Int]], givens: [[Bool]]? = nil) throws {
        try SudokuRules.validate(values: values)

        if let givens {
            guard givens.count == SudokuRules.gridSize,
                  givens.allSatisfy({ $0.count == SudokuRules.gridSize }) else {
                throw SudokuBoardError.invalidDimensions
            }
        }

        cells = try values.enumerated().map { row, values in
            try values.enumerated().map { column, value in
                let isGiven = (givens?[row][column]) ?? (value != 0)
                return try Cell(value: value, isGiven: isGiven)
            }
        }
    }

    /// Creates an empty board whose cells are all editable.
    public init() {
        cells = Array(
            repeating: Array(repeating: try! Cell(value: 0, isGiven: false), count: SudokuRules.gridSize),
            count: SudokuRules.gridSize
        )
    }

    /// Reads the cell at a zero-based coordinate.
    ///
    /// - Throws: `SudokuBoardError.invalidCoordinate` for coordinates outside
    ///   the board.
    public func readCell(row: Int, column: Int) throws -> Cell {
        try SudokuRules.validateCoordinate(row: row, column: column)
        return cells[row][column]
    }

    /// Places a value in an editable cell.
    ///
    /// `0` clears the cell. A nonzero value that conflicts with a row, column,
    /// or box peer is rejected without changing the board.
    public mutating func setValue(_ value: Int, row: Int, column: Int) throws {
        try SudokuRules.validateCoordinate(row: row, column: column)
        guard (0...9).contains(value) else {
            throw SudokuBoardError.invalidCellValue(value)
        }
        guard cells[row][column].isEditable else {
            throw SudokuBoardError.cannotModifyGiven(row: row, column: column)
        }
        guard try !wouldConflict(value: value, row: row, column: column) else {
            throw SudokuBoardError.conflictingMove(value: value, row: row, column: column)
        }

        cells[row][column].setValue(value)
    }

    /// Clears an editable cell at a zero-based coordinate.
    ///
    /// - Throws: `SudokuBoardError.cannotModifyGiven` for a given cell.
    public mutating func clearCell(row: Int, column: Int) throws {
        try setValue(0, row: row, column: column)
    }

    /// Returns whether the existing value at a coordinate conflicts with a
    /// nonzero peer. Empty cells never conflict.
    public func hasConflict(row: Int, column: Int) throws -> Bool {
        try SudokuRules.hasConflict(in: values, row: row, column: column)
    }

    /// Returns whether a value would conflict at a coordinate, ignoring the
    /// target cell itself.
    public func wouldConflict(value: Int, row: Int, column: Int) throws -> Bool {
        try SudokuRules.wouldConflict(in: values, value: value, row: row, column: column)
    }

    /// `true` when every cell contains a nonzero value, even if the completed
    /// board has rule conflicts. Use `isSolved` to require a valid solution.
    public var isComplete: Bool {
        cells.allSatisfy { row in row.allSatisfy { $0.value != 0 } }
    }

    /// `true` only when the board is complete and satisfies every Sudoku rule.
    public var isSolved: Bool {
        (try? SudokuRules.isSolved(values)) ?? false
    }

    public var values: [[Int]] {
        cells.map { $0.map(\.value) }
    }
}
