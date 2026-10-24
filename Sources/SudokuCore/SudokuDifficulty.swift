/// The measurable difficulty labels used for generated Sudoku puzzles.
public enum SudokuDifficulty: String, CaseIterable, Codable, Equatable, Sendable {
    case easy
    case medium
    case hard
}

/// Deterministic solver-effort measurements used to classify a puzzle.
///
/// Single placements reflect the successful solving path. Decisions and
/// backtracks reflect total search effort, including rejected branches.
public struct SudokuDifficultyAnalysis: Equatable, Sendable {
    public let difficulty: SudokuDifficulty
    public let nakedSinglePlacements: Int
    public let hiddenSinglePlacements: Int
    public let backtrackingDecisions: Int
    public let backtrackingBacktracks: Int
}

/// Errors returned when a grid cannot be classified as a playable puzzle.
public enum SudokuDifficultyClassifierError: Error, Equatable, Sendable {
    case notUniquelySolvable(solutionCount: Int)
}

/// Classifies uniquely solvable Sudoku puzzles using deterministic solver effort.
///
/// The rubric is deliberately independent of clue count: Easy puzzles solve
/// with naked singles only; Medium puzzles require hidden singles but no
/// backtracking; Hard puzzles require at least one backtracking decision after
/// both single techniques are exhausted.
public enum SudokuDifficultyClassifier {
    /// Analyzes a uniquely solvable puzzle and returns its measurable effort.
    ///
    /// - Throws: `SudokuBoardError` for malformed grids or invalid values, or
    ///   `SudokuDifficultyClassifierError.notUniquelySolvable` when the grid
    ///   has zero or more than one solution.
    public static func analyze(_ values: [[Int]]) throws -> SudokuDifficultyAnalysis {
        try SudokuRules.validate(values: values)
        let solutionCount = try SudokuSolutionCounter.countSolutions(in: values)
        guard solutionCount == 1 else {
            throw SudokuDifficultyClassifierError.notUniquelySolvable(solutionCount: solutionCount)
        }

        var grid = values
        var nakedSingles = 0
        var hiddenSingles = 0
        var decisions = 0
        var backtracks = 0
        if !isComplete(grid) {
            _ = solveWithBacktracking(
                &grid,
                nakedSingles: &nakedSingles,
                hiddenSingles: &hiddenSingles,
                decisions: &decisions,
                backtracks: &backtracks
            )
        }

        let difficulty: SudokuDifficulty
        if decisions > 0 {
            difficulty = .hard
        } else if hiddenSingles > 0 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }

        return SudokuDifficultyAnalysis(
            difficulty: difficulty,
            nakedSinglePlacements: nakedSingles,
            hiddenSinglePlacements: hiddenSingles,
            backtrackingDecisions: decisions,
            backtrackingBacktracks: backtracks
        )
    }

    /// Returns the difficulty label for a uniquely solvable puzzle.
    public static func classify(_ values: [[Int]]) throws -> SudokuDifficulty {
        try analyze(values).difficulty
    }

    private static func applySingleTechniques(
        to grid: inout [[Int]],
        nakedSingles: inout Int,
        hiddenSingles: inout Int
    ) {
        while true {
            if let move = nextNakedSingle(in: grid) {
                grid[move.row][move.column] = move.value
                nakedSingles += 1
                continue
            }
            if let move = nextHiddenSingle(in: grid) {
                grid[move.row][move.column] = move.value
                hiddenSingles += 1
                continue
            }
            return
        }
    }

    private static func nextNakedSingle(in grid: [[Int]]) -> (row: Int, column: Int, value: Int)? {
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where grid[row][column] == 0 {
                let candidates = candidates(in: grid, row: row, column: column)
                if candidates.count == 1 {
                    return (row, column, candidates[0])
                }
            }
        }
        return nil
    }

    private static func nextHiddenSingle(in grid: [[Int]]) -> (row: Int, column: Int, value: Int)? {
        for unit in units {
            for value in 1...SudokuRules.gridSize {
                guard !unit.contains(where: { grid[$0.row][$0.column] == value }) else {
                    continue
                }

                let matchingCells = unit.filter { coordinate in
                    grid[coordinate.row][coordinate.column] == 0
                        && candidates(in: grid, row: coordinate.row, column: coordinate.column).contains(value)
                }
                if matchingCells.count == 1 {
                    let coordinate = matchingCells[0]
                    return (coordinate.row, coordinate.column, value)
                }
            }
        }
        return nil
    }

    private static func solveWithBacktracking(
        _ grid: inout [[Int]],
        nakedSingles: inout Int,
        hiddenSingles: inout Int,
        decisions: inout Int,
        backtracks: inout Int
    ) -> Bool {
        applySingleTechniques(
            to: &grid,
            nakedSingles: &nakedSingles,
            hiddenSingles: &hiddenSingles
        )

        guard let nextCell = nextEmptyCell(in: grid) else {
            return true
        }

        if nextCell.candidates.count > 1 {
            decisions += 1
        }
        for value in nextCell.candidates {
            let gridBeforeBranch = grid
            let nakedSinglesBeforeBranch = nakedSingles
            let hiddenSinglesBeforeBranch = hiddenSingles
            grid[nextCell.row][nextCell.column] = value
            if solveWithBacktracking(
                &grid,
                nakedSingles: &nakedSingles,
                hiddenSingles: &hiddenSingles,
                decisions: &decisions,
                backtracks: &backtracks
            ) {
                return true
            }
            grid = gridBeforeBranch
            nakedSingles = nakedSinglesBeforeBranch
            hiddenSingles = hiddenSinglesBeforeBranch
            backtracks += 1
        }
        return false
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

    private static func isComplete(_ grid: [[Int]]) -> Bool {
        grid.allSatisfy { row in row.allSatisfy { $0 != 0 } }
    }

    private static let units: [[(row: Int, column: Int)]] = {
        let rows = (0..<SudokuRules.gridSize).map { row in
            (0..<SudokuRules.gridSize).map { column in (row, column) }
        }
        let columns = (0..<SudokuRules.gridSize).map { column in
            (0..<SudokuRules.gridSize).map { row in (row, column) }
        }
        let boxes = (0..<SudokuRules.boxSize).flatMap { boxRow in
            (0..<SudokuRules.boxSize).map { boxColumn in
                (0..<SudokuRules.boxSize).flatMap { rowOffset in
                    (0..<SudokuRules.boxSize).map { columnOffset in
                        (
                            boxRow * SudokuRules.boxSize + rowOffset,
                            boxColumn * SudokuRules.boxSize + columnOffset
                        )
                    }
                }
            }
        }
        return rows + columns + boxes
    }()
}
