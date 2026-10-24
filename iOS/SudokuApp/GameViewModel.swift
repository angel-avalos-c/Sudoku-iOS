import Combine
import SudokuCore

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var board: Board
    @Published private(set) var selectedCell: CellCoordinate?
    @Published private(set) var status: GameStatus
    @Published private(set) var feedback: String?
    @Published private(set) var selectedDifficulty: SudokuDifficulty
    @Published private(set) var isGenerating: Bool
    @Published private(set) var notes: [[Set<Int>]]
    @Published private(set) var isNoteEntryEnabled: Bool
    @Published private(set) var hintsUsed: Int

    private var session: GameSession?
    private let makeSession: @Sendable (SudokuDifficulty) throws -> GameSession
    private let makeNextSession: @Sendable (GameSession, SudokuDifficulty) throws -> GameSession
    private let sessionStore: (any GameSessionPersisting)?

    init(puzzle: Puzzle = PuzzleCatalog.starter, sessionStore: (any GameSessionPersisting)? = nil) {
        board = Board()
        selectedCell = nil
        status = .inProgress
        feedback = nil
        selectedDifficulty = .easy
        isGenerating = false
        notes = Array(repeating: Array(repeating: Set<Int>(), count: SudokuRules.gridSize), count: SudokuRules.gridSize)
        isNoteEntryEnabled = false
        hintsUsed = 0
        makeSession = { try GameSession(difficulty: $0) }
        makeNextSession = { currentSession, difficulty in
            var nextSession = currentSession
            try nextSession.newGame(difficulty: difficulty)
            return nextSession
        }
        self.sessionStore = sessionStore

        do {
            let session = try GameSession(puzzle: puzzle)
            self.session = session
            synchronize(from: session)
        } catch {
            session = nil
            feedback = Self.message(for: error)
        }
    }

    /// Starts a session with a generated puzzle without blocking the main actor.
    convenience init(difficulty: SudokuDifficulty) {
        self.init(
            difficulty: difficulty,
            sessionFactory: { try GameSession(difficulty: $0) },
            sessionStore: UserDefaultsGameSessionStore()
        )
    }

    init(
        difficulty: SudokuDifficulty,
        sessionFactory: @escaping @Sendable (SudokuDifficulty) throws -> GameSession,
        nextSessionFactory: @escaping @Sendable (GameSession, SudokuDifficulty) throws -> GameSession = { currentSession, difficulty in
            var nextSession = currentSession
            try nextSession.newGame(difficulty: difficulty)
            return nextSession
        },
        sessionStore: (any GameSessionPersisting)? = nil
    ) {
        board = Board()
        selectedCell = nil
        status = .inProgress
        feedback = nil
        selectedDifficulty = difficulty
        isGenerating = true
        notes = Array(repeating: Array(repeating: Set<Int>(), count: SudokuRules.gridSize), count: SudokuRules.gridSize)
        isNoteEntryEnabled = false
        hintsUsed = 0
        session = nil
        makeSession = sessionFactory
        makeNextSession = nextSessionFactory
        self.sessionStore = sessionStore

        if let restoredSession = restoreSession() {
            session = restoredSession
            selectedDifficulty = restoredSession.difficulty ?? difficulty
            isGenerating = false
            synchronize(from: restoredSession)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            await startGeneratedSession(difficulty: difficulty)
        }
    }

    func selectCell(row: Int, column: Int) {
        guard !isGenerating else { return }

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
        guard !isGenerating else { return }

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
        guard !isGenerating else { return }

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

    /// Uses the number pad either to enter a value or toggle a candidate note.
    func enterFromNumberPad(_ value: Int) {
        if isNoteEntryEnabled {
            toggleNote(value)
        } else {
            enter(value)
        }
    }

    func toggleNoteEntry() {
        guard !isGenerating else { return }
        isNoteEntryEnabled.toggle()
    }

    func toggleNote(_ value: Int) {
        guard !isGenerating else { return }

        guard session != nil else {
            reportUnavailableSession()
            return
        }

        guard let selectedCell else {
            feedback = "Select an editable cell first."
            return
        }

        apply { try $0.toggleNote(value, row: selectedCell.row, column: selectedCell.column) }
    }

    func applyHint() {
        guard !isGenerating else { return }

        guard var currentSession = session else {
            reportUnavailableSession()
            return
        }

        do {
            guard try currentSession.applyHint() != nil else {
                feedback = "No valid hint is available."
                return
            }
            session = currentSession
            feedback = nil
            synchronize(from: currentSession)
        } catch {
            session = currentSession
            synchronize(from: currentSession)
            feedback = Self.message(for: error)
        }
    }

    func selectDifficulty(_ difficulty: SudokuDifficulty) {
        guard !isGenerating else { return }
        selectedDifficulty = difficulty
    }

    func newGame() {
        guard !isGenerating else { return }

        let difficulty = selectedDifficulty
        guard let currentSession = session else {
            feedback = nil
            isGenerating = true
            Task { [weak self] in
                guard let self else { return }
                await startGeneratedSession(difficulty: difficulty)
            }
            return
        }
        feedback = nil
        isGenerating = true
        Task { [weak self] in
            guard let self else { return }
            await replaceWithGeneratedGame(currentSession, difficulty: difficulty)
        }
    }

    func reset() {
        guard !isGenerating else { return }

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
        guard !isGenerating else { return }

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
        notes = session.notes
        hintsUsed = session.hintsUsed
        sessionStore?.save(session.snapshot())
    }

    private func restoreSession() -> GameSession? {
        guard let snapshot = sessionStore?.load() else { return nil }
        do {
            return try GameSession(snapshot: snapshot)
        } catch {
            sessionStore?.remove()
            return nil
        }
    }

    private func startGeneratedSession(difficulty: SudokuDifficulty) async {
        do {
            let makeSession = makeSession
            let generatedSession = try await Task.detached(priority: .userInitiated) {
                try makeSession(difficulty)
            }.value
            session = generatedSession
            feedback = nil
            synchronize(from: generatedSession)
            isNoteEntryEnabled = false
        } catch {
            session = nil
            feedback = "Unable to start the selected puzzle. Please try again."
        }
        isGenerating = false
    }

    private func replaceWithGeneratedGame(
        _ currentSession: GameSession,
        difficulty: SudokuDifficulty
    ) async {
        do {
            let makeNextSession = makeNextSession
            let generatedSession = try await Task.detached(priority: .userInitiated) {
                try makeNextSession(currentSession, difficulty)
            }.value
            session = generatedSession
            feedback = nil
            synchronize(from: generatedSession)
            isNoteEntryEnabled = false
        } catch {
            // The detached copy ensures a failed generation cannot mutate the
            // live session.
            session = currentSession
            synchronize(from: currentSession)
            feedback = Self.message(for: error)
        }
        isGenerating = false
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
        case GameSessionError.unableToGenerateNewPuzzle:
            return "Unable to generate a new puzzle. Please try again."
        case GameSessionError.invalidNoteValue:
            return "Choose a note from 1 to 9."
        case GameSessionError.cannotAddNoteToFilledCell:
            return "Clear this cell before adding notes."
        case SudokuPuzzleGeneratorError.unableToGenerateDifficulty:
            return "Unable to generate the selected difficulty. Please try again."
        default:
            return "That move could not be applied."
        }
    }
}
