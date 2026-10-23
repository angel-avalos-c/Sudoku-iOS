import Testing
@testable import SudokuCore

struct GameSessionTests {
    @Test func startsWithPuzzleStateAndTracksSelection() throws {
        var session = try GameSession()

        #expect(session.board.values == PuzzleCatalog.starter.givens)
        #expect(session.status == .inProgress)
        #expect(session.selectedCell == nil)
        #expect(session.lastMoveError == nil)

        try session.selectCell(row: 0, column: 0)
        #expect(session.selectedCell == CellCoordinate(row: 0, column: 0))
        #expect(throws: SudokuBoardError.invalidCoordinate(row: -1, column: 0)) {
            try session.selectCell(row: -1, column: 0)
        }
        #expect(session.selectedCell == CellCoordinate(row: 0, column: 0))
        #expect(throws: SudokuBoardError.invalidCoordinate(row: 0, column: 9)) {
            try session.selectCell(row: 0, column: 9)
        }
        #expect(session.selectedCell == CellCoordinate(row: 0, column: 0))
        session.clearSelection()
        #expect(session.selectedCell == nil)
    }

    @Test func preservesGivensAndReportsRejectedMovesWithoutChangingBoard() throws {
        var session = try GameSession()
        let originalBoard = session.board

        #expect(throws: SudokuBoardError.cannotModifyGiven(row: 0, column: 0)) {
            try session.setValue(4, row: 0, column: 0)
        }
        #expect(session.board == originalBoard)
        #expect(session.lastMoveError == .cannotModifyGiven(row: 0, column: 0))

        #expect(throws: SudokuBoardError.conflictingMove(value: 5, row: 0, column: 2)) {
            try session.setValue(5, row: 0, column: 2)
        }
        #expect(session.board == originalBoard)
        #expect(session.lastMoveError == .conflictingMove(value: 5, row: 0, column: 2))
    }

    @Test func supportsEditsWithoutAnUndoStackAndClearsSuccessfulFeedback() throws {
        var session = try GameSession()

        #expect(throws: SudokuBoardError.conflictingMove(value: 5, row: 0, column: 2)) {
            try session.setValue(5, row: 0, column: 2)
        }
        try session.setValue(4, row: 0, column: 2)
        #expect(try session.board.readCell(row: 0, column: 2).value == 4)
        #expect(session.lastMoveError == nil)
        try session.clearCell(row: 0, column: 2)
        #expect(try session.board.readCell(row: 0, column: 2).value == 0)
    }

    @Test func completesOnlyAfterTheValidSolutionAndResetRestoresOriginalState() throws {
        var session = try GameSession()

        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize
            where PuzzleCatalog.starter.givens[row][column] == 0 && !(row == 8 && column == 6) {
                try session.setValue(PuzzleCatalog.starter.solution[row][column], row: row, column: column)
            }
        }

        #expect(session.status == .inProgress)
        try session.setValue(PuzzleCatalog.starter.solution[8][6], row: 8, column: 6)
        #expect(session.board.isSolved)
        #expect(session.status == .completed)

        try session.reset()
        #expect(session.board.values == PuzzleCatalog.starter.givens)
        #expect(session.status == .inProgress)
        #expect(session.selectedCell == nil)
        #expect(session.lastMoveError == nil)
        try session.setValue(PuzzleCatalog.starter.solution[0][2], row: 0, column: 2)
        #expect(try session.board.readCell(row: 0, column: 2).value == 4)
        #expect(session.status == .inProgress)
    }

    @Test func completedGamesRejectEditsAndPreserveSessionState() throws {
        var session = try GameSession()
        try complete(&session)
        try session.selectCell(row: 0, column: 2)
        let completedSession = session

        #expect(throws: GameSessionError.gameAlreadyCompleted) {
            try session.setValue(0, row: 0, column: 2)
        }
        #expect(session == completedSession)
        #expect(throws: GameSessionError.gameAlreadyCompleted) {
            try session.clearCell(row: 0, column: 2)
        }
        #expect(session == completedSession)

        try session.selectCell(row: 0, column: 0)
        #expect(session.selectedCell == CellCoordinate(row: 0, column: 0))
        session.clearSelection()
        #expect(session.selectedCell == nil)
    }

    @Test func startsDynamicSessionsWithTheRequestedDifficulty() throws {
        let firstSession = try GameSession(difficulty: .medium, seed: 0)
        let secondSession = try GameSession(difficulty: .medium, seed: 0)

        #expect(firstSession == secondSession)
        #expect(firstSession.difficulty == .medium)
        #expect(firstSession.board.values == firstSession.puzzle.givens)
        #expect(try SudokuDifficultyClassifier.classify(firstSession.puzzle.givens) == .medium)
        #expect(try SudokuSolutionCounter.countSolutions(in: firstSession.puzzle.givens) == 1)
    }

    @Test func resetRestoresTheCurrentGeneratedPuzzleWithoutReplacement() throws {
        var session = try GameSession(difficulty: .easy, seed: 0)
        let originalPuzzle = session.puzzle
        let editableCell = firstEditableCell(in: originalPuzzle)

        try session.selectCell(row: editableCell.row, column: editableCell.column)
        try session.setValue(
            originalPuzzle.solution[editableCell.row][editableCell.column],
            row: editableCell.row,
            column: editableCell.column
        )
        try session.reset()

        #expect(session.puzzle == originalPuzzle)
        #expect(session.board.values == originalPuzzle.givens)
        #expect(session.difficulty == .easy)
        #expect(session.selectedCell == nil)
        #expect(session.lastMoveError == nil)
    }

    @Test func newGameReplacesThePuzzleAndClearsSessionState() throws {
        var session = try GameSession(difficulty: .easy, seed: 0)
        let originalPuzzle = session.puzzle
        let editableCell = firstEditableCell(in: originalPuzzle)

        try session.selectCell(row: editableCell.row, column: editableCell.column)
        try session.setValue(
            originalPuzzle.solution[editableCell.row][editableCell.column],
            row: editableCell.row,
            column: editableCell.column
        )
        try session.newGame(difficulty: .medium)

        #expect(session.puzzle != originalPuzzle)
        #expect(session.difficulty == .medium)
        #expect(session.board.values == session.puzzle.givens)
        #expect(session.selectedCell == nil)
        #expect(session.lastMoveError == nil)
        #expect(session.status == .inProgress)
        #expect(try SudokuDifficultyClassifier.classify(session.puzzle.givens) == .medium)
    }

    @Test func seededNewGameSequencesAreReproducible() throws {
        var firstSession = try GameSession(difficulty: .easy, seed: 0)
        var secondSession = try GameSession(difficulty: .easy, seed: 0)

        try firstSession.newGame(difficulty: .medium)
        try secondSession.newGame(difficulty: .medium)
        #expect(firstSession == secondSession)

        let firstReplacement = firstSession.puzzle
        try firstSession.newGame(difficulty: .easy)
        try secondSession.newGame(difficulty: .easy)
        #expect(firstSession == secondSession)
        #expect(firstSession.puzzle.givens != firstReplacement.givens)
    }

    @Test func failedNewGamePreservesTheEntireSession() throws {
        var session = try GameSession(difficulty: .easy, seed: 0)
        try session.selectCell(row: 0, column: 0)
        let originalSession = session

        #expect(throws: GameSessionError.unableToGenerateNewPuzzle(.hard, attempts: 3)) {
            try session.newGame(difficulty: .hard, maximumGenerationAttempts: 1)
        }
        #expect(session == originalSession)
    }

    @Test func unexpectedNewGameGenerationErrorsPropagateWithoutMutation() throws {
        var session = try GameSession(difficulty: .easy, seed: 0)
        let originalSession = session

        #expect(throws: SudokuPuzzleGeneratorError.invalidGenerationAttemptLimit(0)) {
            try session.newGame(difficulty: .easy, maximumGenerationAttempts: 0)
        }
        #expect(session == originalSession)
    }
}

private func complete(_ session: inout GameSession) throws {
    for row in 0..<SudokuRules.gridSize {
        for column in 0..<SudokuRules.gridSize where PuzzleCatalog.starter.givens[row][column] == 0 {
            try session.setValue(PuzzleCatalog.starter.solution[row][column], row: row, column: column)
        }
    }
    #expect(session.status == .completed)
}

private func firstEditableCell(in puzzle: Puzzle) -> CellCoordinate {
    for row in 0..<SudokuRules.gridSize {
        for column in 0..<SudokuRules.gridSize where puzzle.givens[row][column] == 0 {
            return CellCoordinate(row: row, column: column)
        }
    }
    fatalError("Generated puzzle unexpectedly has no editable cells.")
}
