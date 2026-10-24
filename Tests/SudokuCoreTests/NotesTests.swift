import Testing
@testable import SudokuCore

struct NotesTests {
    @Test func togglesCandidatesOnlyOnEditableEmptyCells() throws {
        var session = try GameSession()

        try session.toggleNote(1, row: 0, column: 2)
        try session.toggleNote(9, row: 0, column: 2)
        #expect(session.notes[0][2] == [1, 9])

        try session.toggleNote(1, row: 0, column: 2)
        #expect(session.notes[0][2] == [9])
        #expect(throws: SudokuBoardError.cannotModifyGiven(row: 0, column: 0)) {
            try session.toggleNote(1, row: 0, column: 0)
        }
        #expect(throws: GameSessionError.invalidNoteValue(0)) {
            try session.toggleNote(0, row: 0, column: 2)
        }
    }

    @Test func valueCommitClearResetAndNewGameClearNotes() throws {
        var session = try GameSession(difficulty: .easy, seed: 42)
        let coordinate = firstEditableCoordinate(in: session.board)
        try session.toggleNote(1, row: coordinate.row, column: coordinate.column)
        try session.setValue(
            session.puzzle.solution[coordinate.row][coordinate.column],
            row: coordinate.row,
            column: coordinate.column
        )
        #expect(session.notes[coordinate.row][coordinate.column].isEmpty)
        #expect(throws: GameSessionError.cannotAddNoteToFilledCell(row: coordinate.row, column: coordinate.column)) {
            try session.toggleNote(2, row: coordinate.row, column: coordinate.column)
        }

        try session.clearCell(row: coordinate.row, column: coordinate.column)
        try session.toggleNote(3, row: coordinate.row, column: coordinate.column)
        try session.reset()
        #expect(session.notes.allSatisfy { $0.allSatisfy(\.isEmpty) })

        try session.toggleNote(4, row: coordinate.row, column: coordinate.column)
        try session.newGame(difficulty: .medium)
        #expect(session.notes.allSatisfy { $0.allSatisfy(\.isEmpty) })
    }

    @Test func rejectedValueEntryPreservesExistingCandidateNotes() throws {
        var session = try GameSession()
        try session.toggleNote(4, row: 0, column: 2)

        #expect(throws: SudokuBoardError.conflictingMove(value: 5, row: 0, column: 2)) {
            try session.setValue(5, row: 0, column: 2)
        }
        #expect(session.notes[0][2] == [4])
    }

    private func firstEditableCoordinate(in board: Board) -> CellCoordinate {
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where board.cells[row][column].isEditable {
                return CellCoordinate(row: row, column: column)
            }
        }
        fatalError("Puzzle unexpectedly has no editable cells.")
    }
}
