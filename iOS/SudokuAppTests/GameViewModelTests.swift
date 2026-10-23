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

    @Test func resetRestoresTheStarterPuzzle() throws {
        let viewModel = GameViewModel()
        let expectedBoard = try Board(values: PuzzleCatalog.starter.givens)

        viewModel.selectCell(row: 0, column: 2)
        viewModel.enter(4)
        viewModel.reset()

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

    @Test func retainsTheSelectedDifficultyForTheNextGeneratedGame() {
        let viewModel = GameViewModel()

        viewModel.selectDifficulty(.hard)

        #expect(viewModel.selectedDifficulty == .hard)
    }

    @Test func generatesTheRequestedPuzzleAsynchronously() async throws {
        let seed: UInt64 = 42
        let expectedSession = try GameSession(difficulty: .easy, seed: seed)
        let viewModel = GameViewModel(difficulty: .easy, sessionFactory: {
            try GameSession(difficulty: $0, seed: seed)
        })

        #expect(viewModel.isGenerating)
        await waitForGeneration(of: viewModel)

        #expect(viewModel.isGenerating == false)
        #expect(viewModel.board == expectedSession.board)
        #expect(viewModel.feedback == nil)
    }

    @Test func resetKeepsTheCurrentPuzzleWhileNewGameReplacesIt() async throws {
        let viewModel = GameViewModel(difficulty: .easy, sessionFactory: {
            try GameSession(difficulty: $0, seed: 42)
        })
        await waitForGeneration(of: viewModel)
        let originalBoard = viewModel.board

        viewModel.reset()
        #expect(viewModel.board == originalBoard)

        viewModel.newGame()
        #expect(viewModel.isGenerating)
        await waitForGeneration(of: viewModel)

        #expect(viewModel.board != originalBoard)
        #expect(viewModel.selectedCell == nil)
        #expect(viewModel.feedback == nil)
    }

    @Test func ignoresGameInteractionsWhileGenerating() async throws {
        let viewModel = GameViewModel(difficulty: .easy, sessionFactory: {
            try GameSession(difficulty: $0, seed: 42)
        })
        await waitForGeneration(of: viewModel)
        let editableCoordinate = firstEditableCoordinate(in: viewModel.board)
        #expect(editableCoordinate != nil)
        guard let editableCoordinate else { return }
        viewModel.selectCell(row: editableCoordinate.row, column: editableCoordinate.column)
        let boardBeforeGeneration = viewModel.board
        let selectionBeforeGeneration = viewModel.selectedCell

        viewModel.newGame()
        viewModel.selectDifficulty(.hard)
        viewModel.selectCell(row: 1, column: 1)
        viewModel.enter(4)
        viewModel.clearSelectedCell()
        viewModel.reset()

        #expect(viewModel.isGenerating)
        #expect(viewModel.selectedDifficulty == .easy)
        #expect(viewModel.board == boardBeforeGeneration)
        #expect(viewModel.selectedCell == selectionBeforeGeneration)

        await waitForGeneration(of: viewModel)
    }

    @Test func failedNewGamePreservesTheCurrentSessionAndCanBeRetried() async throws {
        let viewModel = GameViewModel(
            difficulty: .easy,
            sessionFactory: { try GameSession(difficulty: $0, seed: 42) },
            nextSessionFactory: { _, difficulty in
                guard difficulty == .medium else {
                    throw SudokuPuzzleGeneratorError.unableToGenerateDifficulty(difficulty, attempts: 1)
                }
                return try GameSession(difficulty: difficulty, seed: 0)
            }
        )
        await waitForGeneration(of: viewModel)
        let editableCoordinate = firstEditableCoordinate(in: viewModel.board)
        #expect(editableCoordinate != nil)
        guard let editableCoordinate else { return }
        viewModel.selectCell(row: editableCoordinate.row, column: editableCoordinate.column)
        let boardBeforeFailure = viewModel.board
        let selectionBeforeFailure = viewModel.selectedCell

        viewModel.newGame()
        #expect(viewModel.isGenerating)
        await waitForGeneration(of: viewModel)

        #expect(viewModel.board == boardBeforeFailure)
        #expect(viewModel.selectedCell == selectionBeforeFailure)
        #expect(viewModel.feedback == "Unable to generate the selected difficulty. Please try again.")
        #expect(viewModel.isGenerating == false)

        viewModel.selectDifficulty(.medium)
        viewModel.newGame()
        #expect(viewModel.isGenerating)
        await waitForGeneration(of: viewModel)
        #expect(viewModel.feedback == nil)
    }

    @Test func newGameRecoversFromAnInitialGenerationFailure() async throws {
        let viewModel = GameViewModel(difficulty: .easy, sessionFactory: { difficulty in
            guard difficulty == .medium else {
                throw SudokuPuzzleGeneratorError.unableToGenerateDifficulty(difficulty, attempts: 1)
            }
            return try GameSession(difficulty: difficulty, seed: 42)
        })

        await waitForGeneration(of: viewModel)
        #expect(viewModel.feedback == "Unable to start the selected puzzle. Please try again.")

        viewModel.newGame()
        #expect(viewModel.isGenerating)
        await waitForGeneration(of: viewModel)
        #expect(viewModel.feedback == "Unable to start the selected puzzle. Please try again.")

        viewModel.selectDifficulty(.medium)
        viewModel.newGame()
        await waitForGeneration(of: viewModel)

        #expect(viewModel.isGenerating == false)
        #expect(viewModel.feedback == nil)
    }

    private func waitForGeneration(of viewModel: GameViewModel) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while viewModel.isGenerating && clock.now < deadline {
            await Task.yield()
        }
        #expect(viewModel.isGenerating == false)
    }

    private func firstEditableCoordinate(in board: Board) -> CellCoordinate? {
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where board.cells[row][column].isEditable {
                return CellCoordinate(row: row, column: column)
            }
        }
        return nil
    }
}
