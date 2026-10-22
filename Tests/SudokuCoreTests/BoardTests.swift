import Testing
@testable import SudokuCore

struct BoardTests {
    @Test func initializesEmptyBoardWithEditableCells() throws {
        let board = Board()

        #expect(board.values == SudokuFixtures.emptyBoard)
        #expect(try board.readCell(row: 0, column: 0).isEditable)
        #expect(!board.isComplete)
        #expect(!board.isSolved)
    }

    @Test func validatesDimensionsCellValuesAndGivens() {
        #expect(throws: SudokuBoardError.invalidDimensions) {
            try Board(values: Array(repeating: Array(repeating: 0, count: 9), count: 8))
        }
        #expect(throws: SudokuBoardError.invalidCellValue(10)) {
            var values = SudokuFixtures.emptyBoard
            values[2][4] = 10
            _ = try Board(values: values)
        }
        #expect(throws: SudokuBoardError.invalidDimensions) {
            var givens = SudokuFixtures.allEditable
            givens.removeLast()
            _ = try Board(values: SudokuFixtures.emptyBoard, givens: givens)
        }
        #expect(throws: SudokuBoardError.invalidDimensions) {
            var givens = SudokuFixtures.allEditable
            givens[4].removeLast()
            _ = try Board(values: SudokuFixtures.emptyBoard, givens: givens)
        }
        #expect(throws: SudokuBoardError.emptyGivenCell) {
            var givens = SudokuFixtures.allEditable
            givens[4][4] = true
            _ = try Board(values: SudokuFixtures.emptyBoard, givens: givens)
        }
        #expect(throws: SudokuBoardError.emptyGivenCell) {
            _ = try Cell(value: 0, isGiven: true)
        }
    }

    @Test func rejectedGivenCellOperationsPreserveTheEntireBoard() throws {
        var board = try Board(values: SudokuFixtures.partialPuzzle)
        let original = board

        #expect(throws: SudokuBoardError.cannotModifyGiven(row: 0, column: 0)) {
            try board.setValue(4, row: 0, column: 0)
        }
        #expect(board == original)
        #expect(throws: SudokuBoardError.cannotModifyGiven(row: 0, column: 0)) {
            try board.clearCell(row: 0, column: 0)
        }
        #expect(board == original)
    }

    @Test func canUpdateAndClearEditableCellsIncludingTheSameValue() throws {
        var board = try Board(values: SudokuFixtures.partialPuzzle)

        try board.setValue(4, row: 0, column: 2)
        #expect(try board.readCell(row: 0, column: 2).value == 4)
        try board.setValue(4, row: 0, column: 2)
        #expect(try board.readCell(row: 0, column: 2).value == 4)
        try board.setValue(1, row: 0, column: 2)
        #expect(try board.readCell(row: 0, column: 2).value == 1)
        try board.clearCell(row: 0, column: 2)
        #expect(try board.readCell(row: 0, column: 2).value == 0)
    }

    @Test func supportsEditableCellsInitializedWithNonzeroValues() throws {
        var values = SudokuFixtures.emptyBoard
        values[4][4] = 5
        var board = try Board(values: values, givens: SudokuFixtures.allEditable)

        #expect(try board.readCell(row: 4, column: 4).isEditable)
        try board.setValue(5, row: 4, column: 4)
        #expect(try board.readCell(row: 4, column: 4).value == 5)
        try board.setValue(6, row: 4, column: 4)
        #expect(try board.readCell(row: 4, column: 4).value == 6)
    }

    @Test func rejectedInvalidValuesAndCoordinatesPreserveTheEntireBoard() throws {
        var board = Board()
        let original = board

        #expect(throws: SudokuBoardError.invalidCoordinate(row: 9, column: 0)) {
            try board.setValue(1, row: 9, column: 0)
        }
        #expect(board == original)
        #expect(throws: SudokuBoardError.invalidCoordinate(row: -1, column: 0)) {
            try board.setValue(1, row: -1, column: 0)
        }
        #expect(board == original)
        #expect(throws: SudokuBoardError.invalidCellValue(10)) {
            try board.setValue(10, row: 0, column: 0)
        }
        #expect(board == original)
        #expect(throws: SudokuBoardError.invalidCellValue(-1)) {
            try board.setValue(-1, row: 0, column: 0)
        }
        #expect(board == original)
    }

    @Test func distinguishesCompleteFromSolved() throws {
        let solved = try Board(values: SudokuFixtures.solution, givens: SudokuFixtures.allEditable)
        let conflicting = try Board(values: SudokuFixtures.conflictingBoard, givens: SudokuFixtures.allEditable)

        #expect(solved.isComplete)
        #expect(solved.isSolved)
        #expect(conflicting.isComplete)
        #expect(!conflicting.isSolved)
    }
}

enum SudokuFixtures {
    static let emptyBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)

    static let partialPuzzle = [
        [5, 3, 0, 0, 7, 0, 0, 0, 0],
        [6, 0, 0, 1, 9, 5, 0, 0, 0],
        [0, 9, 8, 0, 0, 0, 0, 6, 0],
        [8, 0, 0, 0, 6, 0, 0, 0, 3],
        [4, 0, 0, 8, 0, 3, 0, 0, 1],
        [7, 0, 0, 0, 2, 0, 0, 0, 6],
        [0, 6, 0, 0, 0, 0, 2, 8, 0],
        [0, 0, 0, 4, 1, 9, 0, 0, 5],
        [0, 0, 0, 0, 8, 0, 0, 7, 9],
    ]

    static let solution = [
        [5, 3, 4, 6, 7, 8, 9, 1, 2],
        [6, 7, 2, 1, 9, 5, 3, 4, 8],
        [1, 9, 8, 3, 4, 2, 5, 6, 7],
        [8, 5, 9, 7, 6, 1, 4, 2, 3],
        [4, 2, 6, 8, 5, 3, 7, 9, 1],
        [7, 1, 3, 9, 2, 4, 8, 5, 6],
        [9, 6, 1, 5, 3, 7, 2, 8, 4],
        [2, 8, 7, 4, 1, 9, 6, 3, 5],
        [3, 4, 5, 2, 8, 6, 1, 7, 9],
    ]

    static let conflictingBoard: [[Int]] = {
        var board = solution
        board[0][0] = 3
        return board
    }()

    static let allEditable = Array(repeating: Array(repeating: false, count: 9), count: 9)
}
