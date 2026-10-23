/// Errors returned by the bounded Sudoku solution counter.
public enum SudokuSolutionCounterError: Error, Equatable, Sendable {
    case invalidLimit(Int)
}

/// Counts Sudoku solutions without searching beyond a caller-supplied bound.
public enum SudokuSolutionCounter {
    /// Counts solutions for a partially filled grid, stopping after `upTo`
    /// solutions have been found.
    ///
    /// The default bound of two distinguishes a unique puzzle from one with
    /// multiple solutions without exhaustively counting every solution. A
    /// well-formed grid with inconsistent nonzero givens has zero solutions.
    ///
    /// - Throws: `SudokuBoardError` for malformed grids or out-of-range values,
    ///   or `SudokuSolutionCounterError.invalidLimit` when `upTo` is not positive.
    public static func countSolutions(in values: [[Int]], upTo limit: Int = 2) throws -> Int {
        guard limit > 0 else {
            throw SudokuSolutionCounterError.invalidLimit(limit)
        }

        try SudokuRules.validate(values: values)
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where values[row][column] != 0 {
                if try SudokuRules.hasConflict(in: values, row: row, column: column) {
                    return 0
                }
            }
        }

        var grid = values
        var solutionCount = 0
        search(&grid, solutionCount: &solutionCount, limit: limit)
        return solutionCount
    }

    private static func search(_ grid: inout [[Int]], solutionCount: inout Int, limit: Int) {
        guard solutionCount < limit else { return }

        guard let nextCell = nextEmptyCell(in: grid) else {
            solutionCount += 1
            return
        }

        for value in nextCell.candidates {
            grid[nextCell.row][nextCell.column] = value
            search(&grid, solutionCount: &solutionCount, limit: limit)
            grid[nextCell.row][nextCell.column] = 0

            guard solutionCount < limit else { return }
        }
    }

    private static func nextEmptyCell(in grid: [[Int]]) -> (row: Int, column: Int, candidates: [Int])? {
        var selectedCell: (row: Int, column: Int, candidates: [Int])?

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where grid[row][column] == 0 {
                let candidates = candidates(in: grid, row: row, column: column)
                if candidates.isEmpty {
                    return (row, column, candidates)
                }
                if selectedCell == nil || candidates.count < selectedCell!.candidates.count {
                    selectedCell = (row, column, candidates)
                }
            }
        }

        return selectedCell
    }

    private static func candidates(in grid: [[Int]], row: Int, column: Int) -> [Int] {
        var unavailable = Array(repeating: false, count: SudokuRules.gridSize + 1)

        for index in 0..<SudokuRules.gridSize {
            unavailable[grid[row][index]] = true
            unavailable[grid[index][column]] = true
        }

        let boxStartRow = (row / SudokuRules.boxSize) * SudokuRules.boxSize
        let boxStartColumn = (column / SudokuRules.boxSize) * SudokuRules.boxSize
        for candidateRow in boxStartRow..<(boxStartRow + SudokuRules.boxSize) {
            for candidateColumn in boxStartColumn..<(boxStartColumn + SudokuRules.boxSize) {
                unavailable[grid[candidateRow][candidateColumn]] = true
            }
        }

        return (1...SudokuRules.gridSize).filter { !unavailable[$0] }
    }
}
