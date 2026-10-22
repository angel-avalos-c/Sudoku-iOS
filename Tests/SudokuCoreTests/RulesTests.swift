import Testing
@testable import SudokuCore

struct RulesTests {
    @Test func identifiesRowColumnAndBoxConflictsAcrossBoardRegions() throws {
        var rowConflict = SudokuFixtures.emptyBoard
        rowConflict[8][0] = 4
        #expect(try SudokuRules.wouldConflict(in: rowConflict, value: 4, row: 8, column: 8))

        var columnConflict = SudokuFixtures.emptyBoard
        columnConflict[0][8] = 5
        #expect(try SudokuRules.wouldConflict(in: columnConflict, value: 5, row: 8, column: 8))

        var boxConflict = SudokuFixtures.emptyBoard
        boxConflict[3][3] = 6
        #expect(try SudokuRules.wouldConflict(in: boxConflict, value: 6, row: 5, column: 5))
        #expect(!(try SudokuRules.wouldConflict(in: boxConflict, value: 7, row: 5, column: 5)))
    }

    @Test func ignoresTheTargetCellWhenCheckingForConflicts() throws {
        #expect(!(try SudokuRules.hasConflict(in: SudokuFixtures.solution, row: 0, column: 0)))
        #expect(try SudokuRules.hasConflict(in: SudokuFixtures.conflictingBoard, row: 0, column: 0))
    }

    @Test func rejectsConflictingMoveWithoutMutatingBoard() throws {
        var board = try Board(values: SudokuFixtures.partialPuzzle)
        let original = board

        #expect(throws: SudokuBoardError.conflictingMove(value: 5, row: 0, column: 2)) {
            try board.setValue(5, row: 0, column: 2)
        }
        #expect(board == original)
    }

    @Test func treatsZeroAsNonConflicting() throws {
        #expect(!(try SudokuRules.wouldConflict(in: SudokuFixtures.partialPuzzle, value: 0, row: 0, column: 2)))
    }

    @Test func publicRuleMethodsRejectInvalidGridsCoordinatesAndValues() {
        let malformedGrid = Array(repeating: Array(repeating: 0, count: 9), count: 8)
        #expect(throws: SudokuBoardError.invalidDimensions) {
            try SudokuRules.validate(values: malformedGrid)
        }
        #expect(throws: SudokuBoardError.invalidDimensions) {
            try SudokuRules.wouldConflict(in: malformedGrid, value: 1, row: 0, column: 0)
        }
        #expect(throws: SudokuBoardError.invalidDimensions) {
            try SudokuRules.isSolved(malformedGrid)
        }

        var invalidValueGrid = SudokuFixtures.emptyBoard
        invalidValueGrid[3][3] = -1
        #expect(throws: SudokuBoardError.invalidCellValue(-1)) {
            try SudokuRules.validate(values: invalidValueGrid)
        }
        #expect(throws: SudokuBoardError.invalidCellValue(-1)) {
            try SudokuRules.hasConflict(in: invalidValueGrid, row: 0, column: 0)
        }
        #expect(throws: SudokuBoardError.invalidCellValue(-1)) {
            try SudokuRules.isSolved(invalidValueGrid)
        }

        #expect(throws: SudokuBoardError.invalidCoordinate(row: -1, column: 0)) {
            try SudokuRules.wouldConflict(in: SudokuFixtures.emptyBoard, value: 1, row: -1, column: 0)
        }
        #expect(throws: SudokuBoardError.invalidCoordinate(row: 0, column: 9)) {
            try SudokuRules.hasConflict(in: SudokuFixtures.emptyBoard, row: 0, column: 9)
        }
        #expect(throws: SudokuBoardError.invalidCellValue(10)) {
            try SudokuRules.wouldConflict(in: SudokuFixtures.emptyBoard, value: 10, row: 0, column: 0)
        }
    }
}
