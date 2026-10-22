import Combine
import SudokuCore

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var board: Board
    @Published private(set) var selectedCell: CellCoordinate?
    @Published private(set) var status: GameStatus
    @Published private(set) var feedback: String?

    private var session: GameSession?

    init(puzzle: Puzzle = PuzzleCatalog.starter) {
        board = Board()
        selectedCell = nil
        status = .inProgress
        feedback = nil

        do {
            let session = try GameSession(puzzle: puzzle)
            self.session = session
            synchronize(from: session)
        } catch {
            session = nil
            feedback = Self.message(for: error)
        }
    }

    func selectCell(row: Int, column: Int) {
        guard var currentSession = session else {
            reportUnavailableSession()
            return
        }

        guard let cell = try? currentSession.board.readCell(row: row, column: column), cell.isEditable else {
            return
        }

        do {
            try currentSession.selectCell(row: row, column: column)
            session = currentSession
            feedback = nil
            synchronize(from: currentSession)
        } catch {
            session = currentSession
            feedback = Self.message(for: error)
        }
    }

    func enter(_ value: Int) {
        guard session != nil else {
            reportUnavailableSession()
            return
        }

        guard let selectedCell else {
            feedback = "Select an editable cell first."
            return
        }

        apply { try $0.setValue(value, row: selectedCell.row, column: selectedCell.column) }
    }

    func clearSelectedCell() {
        guard session != nil else {
            reportUnavailableSession()
            return
        }

        guard let selectedCell else {
            feedback = "Select an editable cell first."
            return
        }

        apply { try $0.clearCell(row: selectedCell.row, column: selectedCell.column) }
    }

    func newGame() {
        guard var currentSession = session else {
            reportUnavailableSession()
            return
        }

        do {
            try currentSession.reset()
            session = currentSession
            feedback = nil
            synchronize(from: currentSession)
        } catch {
            session = currentSession
            synchronize(from: currentSession)
            feedback = Self.message(for: error)
        }
    }

    func cell(row: Int, column: Int) -> Cell {
        board.cells[row][column]
    }

    private func apply(_ operation: (inout GameSession) throws -> Void) {
        guard var currentSession = session else {
            reportUnavailableSession()
            return
        }

        do {
            try operation(&currentSession)
            session = currentSession
            feedback = nil
            synchronize(from: currentSession)
        } catch {
            session = currentSession
            synchronize(from: currentSession)
            feedback = Self.message(for: error)
        }
    }

    private func synchronize(from session: GameSession) {
        board = session.board
        selectedCell = session.selectedCell
        status = session.status
    }

    private func reportUnavailableSession() {
        feedback = "Unable to start the selected puzzle."
    }

    private static func message(for error: Error) -> String {
        switch error {
        case SudokuBoardError.conflictingMove:
            return "That number conflicts with the current board."
        case SudokuBoardError.cannotModifyGiven:
            return "Given cells cannot be changed."
        case SudokuBoardError.invalidCellValue:
            return "Choose a number from 1 to 9."
        case SudokuBoardError.invalidCoordinate:
            return "That cell is unavailable."
        case GameSessionError.gameAlreadyCompleted:
            return "This puzzle is complete. Start a new game to keep playing."
        default:
            return "That move could not be applied."
        }
    }
}
