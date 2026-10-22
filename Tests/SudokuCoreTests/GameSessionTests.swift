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
}

private func complete(_ session: inout GameSession) throws {
    for row in 0..<SudokuRules.gridSize {
        for column in 0..<SudokuRules.gridSize where PuzzleCatalog.starter.givens[row][column] == 0 {
            try session.setValue(PuzzleCatalog.starter.solution[row][column], row: row, column: column)
        }
    }
    #expect(session.status == .completed)
}
