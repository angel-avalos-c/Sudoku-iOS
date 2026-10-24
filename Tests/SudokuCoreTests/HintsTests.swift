import Testing
@testable import SudokuCore

struct HintsTests {
    @Test func appliesTheFirstLegalSolutionValueDeterministically() throws {
        var session = try GameSession()
        try session.toggleNote(1, row: 0, column: 2)

        let hint = try session.applyHint()
        #expect(hint != nil)
        guard let hint else { return }
        #expect(hint == GameHint(coordinate: CellCoordinate(row: 0, column: 2), value: 4))
        #expect(session.board.values[0][2] == 4)
        #expect(session.notes[0][2].isEmpty)
        #expect(session.hintsUsed == 1)

        let restored = try GameSession(snapshot: session.snapshot())
        #expect(restored.hintsUsed == 1)
        #expect(restored.board.values[0][2] == 4)
    }

    @Test func resetAndNewGameStartWithNoHintsUsed() throws {
        var session = try GameSession(difficulty: .easy, seed: 42)
        let firstHint = try session.applyHint()
        #expect(firstHint != nil)
        #expect(session.hintsUsed == 1)

        try session.reset()
        #expect(session.hintsUsed == 0)

        let secondHint = try session.applyHint()
        #expect(secondHint != nil)
        try session.newGame(difficulty: .medium)
        #expect(session.hintsUsed == 0)
    }

    @Test func returnsNilWithoutMutationWhenNoLegalHintIsAvailable() throws {
        let solution = PuzzleCatalog.starter.solution
        let emptyPuzzle = try Puzzle(
            givens: Array(repeating: Array(repeating: 0, count: SudokuRules.gridSize), count: SudokuRules.gridSize),
            solution: solution
        )
        var session = try GameSession(puzzle: emptyPuzzle)
        let unavailableCoordinate = CellCoordinate(row: 0, column: 7)
        let alternateSolution = solution.map { row in
            row.map { value in
                switch value {
                case 1: return 2
                case 2: return 1
                default: return value
                }
            }
        }

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize
            where CellCoordinate(row: row, column: column) != unavailableCoordinate {
                try session.setValue(alternateSolution[row][column], row: row, column: column)
            }
        }
        let stateBeforeHint = session

        let hint = try session.applyHint()
        #expect(hint == nil)
        #expect(session == stateBeforeHint)
        #expect(session.hintsUsed == 0)
    }

    @Test func rejectsHintsForCompletedGamesWithoutMutation() throws {
        var session = try GameSession()
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where session.puzzle.givens[row][column] == 0 {
                try session.setValue(session.puzzle.solution[row][column], row: row, column: column)
            }
        }
        let completedSession = session

        #expect(throws: GameSessionError.gameAlreadyCompleted) {
            try session.applyHint()
        }
        #expect(session == completedSession)
    }
}
