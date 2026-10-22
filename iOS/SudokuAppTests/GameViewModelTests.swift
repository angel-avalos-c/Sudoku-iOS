import Testing
@testable import SudokuApp
import SudokuCore

@MainActor
struct GameViewModelTests {
    @Test func selectsEditableCellsButLeavesSelectionOnGivenCells() {
        let viewModel = GameViewModel()

        viewModel.selectCell(row: 0, column: 2)
        #expect(viewModel.selectedCell == CellCoordinate(row: 0, column: 2))
        viewModel.selectCell(row: 0, column: 0)
        #expect(viewModel.selectedCell == CellCoordinate(row: 0, column: 2))
    }

    @Test func reportsConflictsWithoutChangingTheBoard() {
        let viewModel = GameViewModel()
        let originalBoard = viewModel.board

        viewModel.selectCell(row: 0, column: 2)
        viewModel.enter(5)

        #expect(viewModel.board == originalBoard)
        #expect(viewModel.feedback == "That number conflicts with the current board.")
    }

    @Test func entersAndClearsAValueThroughGameSession() {
        let viewModel = GameViewModel()

        viewModel.selectCell(row: 0, column: 2)
        viewModel.enter(4)
        #expect(viewModel.cell(row: 0, column: 2).value == 4)
        #expect(viewModel.feedback == nil)
        viewModel.clearSelectedCell()
        #expect(viewModel.cell(row: 0, column: 2).value == 0)
    }

    @Test func enteringOrClearingWithoutSelectionReportsFeedback() {
        let viewModel = GameViewModel()

        viewModel.enter(4)
        #expect(viewModel.feedback == "Select an editable cell first.")

        viewModel.clearSelectedCell()
        #expect(viewModel.feedback == "Select an editable cell first.")
    }

    @Test func newGameRestoresTheStarterPuzzle() throws {
        let viewModel = GameViewModel()
        let expectedBoard = try Board(values: PuzzleCatalog.starter.givens)

        viewModel.selectCell(row: 0, column: 2)
        viewModel.enter(4)
        viewModel.newGame()

        #expect(viewModel.board == expectedBoard)
        #expect(viewModel.selectedCell == nil)
        #expect(viewModel.status == .inProgress)
        #expect(viewModel.feedback == nil)
    }

    @Test func successfulSelectionClearsStaleFeedback() {
        let viewModel = GameViewModel()

        viewModel.enter(4)
        #expect(viewModel.feedback == "Select an editable cell first.")

        viewModel.selectCell(row: 0, column: 2)
        #expect(viewModel.selectedCell == CellCoordinate(row: 0, column: 2))
        #expect(viewModel.feedback == nil)
    }
}
