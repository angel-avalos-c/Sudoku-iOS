/// Stateless validation helpers for a standard 9 by 9 Sudoku grid.
public enum SudokuRules {
    public static let gridSize = 9
    public static let boxSize = 3

    /// Validates that a grid has nine rows of nine values in `0...9`.
    ///
    /// - Throws: `SudokuBoardError.invalidDimensions` for a non-9 by 9 grid,
    ///   or `SudokuBoardError.invalidCellValue` for an out-of-range value.
    public static func validate(values: [[Int]]) throws {
        guard values.count == gridSize, values.allSatisfy({ $0.count == gridSize }) else {
            throw SudokuBoardError.invalidDimensions
        }

        for row in values {
            for value in row where !(0...9).contains(value) {
                throw SudokuBoardError.invalidCellValue(value)
            }
        }
    }

    /// Returns whether placing `value` at a zero-based coordinate would
    /// duplicate a nonzero value in its row, column, or 3 by 3 box.
    /// The target coordinate itself is ignored.
    ///
    /// - Throws: A typed board error for malformed grids, coordinates outside
    ///   `0...8`, or values outside `0...9`.
    public static func wouldConflict(
        in values: [[Int]],
        value: Int,
        row: Int,
        column: Int
    ) throws -> Bool {
        try validate(values: values)
        try validateCoordinate(row: row, column: column)

        guard (0...9).contains(value) else {
            throw SudokuBoardError.invalidCellValue(value)
        }
        guard value != 0 else { return false }

        for index in 0..<gridSize where index != column && values[row][index] == value {
            return true
        }
        for index in 0..<gridSize where index != row && values[index][column] == value {
            return true
        }

        let boxStartRow = (row / boxSize) * boxSize
        let boxStartColumn = (column / boxSize) * boxSize
        for candidateRow in boxStartRow..<(boxStartRow + boxSize) {
            for candidateColumn in boxStartColumn..<(boxStartColumn + boxSize)
            where (candidateRow != row || candidateColumn != column)
                && values[candidateRow][candidateColumn] == value {
                return true
            }
        }

        return false
    }

    /// Returns whether the nonzero value already at a zero-based coordinate
    /// conflicts with a peer. Empty cells never conflict.
    public static func hasConflict(in values: [[Int]], row: Int, column: Int) throws -> Bool {
        try validate(values: values)
        try validateCoordinate(row: row, column: column)
        return try wouldConflict(in: values, value: values[row][column], row: row, column: column)
    }

    /// Returns `true` only for a completely filled grid with no row, column,
    /// or box conflicts.
    public static func isSolved(_ values: [[Int]]) throws -> Bool {
        try validate(values: values)

        for row in 0..<gridSize {
            for column in 0..<gridSize {
                guard values[row][column] != 0,
                      try !hasConflict(in: values, row: row, column: column) else {
                    return false
                }
            }
        }
        return true
    }

    static func validateCoordinate(row: Int, column: Int) throws {
        guard (0..<gridSize).contains(row), (0..<gridSize).contains(column) else {
            throw SudokuBoardError.invalidCoordinate(row: row, column: column)
        }
    }
}
