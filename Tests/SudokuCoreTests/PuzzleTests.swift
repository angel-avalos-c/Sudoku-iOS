import Testing
@testable import SudokuCore

struct PuzzleTests {
    @Test func catalogPuzzleIsValidAndReproducible() throws {
        let puzzle = PuzzleCatalog.starter
        let firstBoard = try puzzle.makeBoard()
        let secondBoard = try puzzle.makeBoard()

        #expect(try SudokuRules.isSolved(puzzle.solution))
        #expect(firstBoard.values == puzzle.givens)
        #expect(firstBoard.values == secondBoard.values)
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize {
                let firstCell = try firstBoard.readCell(row: row, column: column)
                let secondCell = try secondBoard.readCell(row: row, column: column)
                #expect(firstCell.isGiven == secondCell.isGiven)
            }
        }
        #expect(try firstBoard.readCell(row: 0, column: 0).isGiven)
        #expect(try firstBoard.readCell(row: 0, column: 2).isEditable)
    }

    @Test func rejectsInvalidPuzzlePairs() throws {
        var conflictingGivens = PuzzleCatalog.starter.givens
        conflictingGivens[0][2] = 5
        #expect(throws: PuzzleError.conflictingGiven(row: 0, column: 0)) {
            _ = try Puzzle(givens: conflictingGivens, solution: PuzzleCatalog.starter.solution)
        }

        var mismatchedGivens = PuzzleCatalog.starter.givens
        mismatchedGivens[0][2] = 2
        #expect(throws: PuzzleError.givenDoesNotMatchSolution(row: 0, column: 2)) {
            _ = try Puzzle(givens: mismatchedGivens, solution: PuzzleCatalog.starter.solution)
        }

        var invalidSolution = PuzzleCatalog.starter.solution
        invalidSolution[0][0] = 3
        #expect(throws: PuzzleError.invalidSolution) {
            _ = try Puzzle(givens: PuzzleCatalog.starter.givens, solution: invalidSolution)
        }
    }

    @Test func rejectsInvalidPuzzleDimensionsAndValues() {
        let malformedGrid = Array(repeating: Array(repeating: 0, count: 9), count: 8)
        #expect(throws: SudokuBoardError.invalidDimensions) {
            _ = try Puzzle(givens: malformedGrid, solution: PuzzleCatalog.starter.solution)
        }
        #expect(throws: SudokuBoardError.invalidDimensions) {
            _ = try Puzzle(givens: PuzzleCatalog.starter.givens, solution: malformedGrid)
        }

        var invalidGivens = PuzzleCatalog.starter.givens
        invalidGivens[0][2] = -1
        #expect(throws: SudokuBoardError.invalidCellValue(-1)) {
            _ = try Puzzle(givens: invalidGivens, solution: PuzzleCatalog.starter.solution)
        }

        var invalidSolution = PuzzleCatalog.starter.solution
        invalidSolution[0][0] = 10
        #expect(throws: SudokuBoardError.invalidCellValue(10)) {
            _ = try Puzzle(givens: PuzzleCatalog.starter.givens, solution: invalidSolution)
        }
    }

    @Test func rejectsIncompleteSolution() {
        var incompleteSolution = PuzzleCatalog.starter.solution
        incompleteSolution[0][2] = 0

        #expect(throws: PuzzleError.invalidSolution) {
            _ = try Puzzle(givens: PuzzleCatalog.starter.givens, solution: incompleteSolution)
        }
    }
}
