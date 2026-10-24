import Foundation
import Testing
@testable import SudokuCore

struct GameSessionSnapshotTests {
    @Test func roundTripsAnInterruptedSessionWithoutChangingGivens() throws {
        var session = try GameSession()
        try session.setValue(4, row: 0, column: 2)
        let snapshot = session.snapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decodedSnapshot = try JSONDecoder().decode(GameSessionSnapshot.self, from: data)
        let restored = try GameSession(snapshot: decodedSnapshot)

        #expect(restored.board.values == session.board.values)
        #expect(restored.puzzle.givens == session.puzzle.givens)
        #expect(restored.board.cells[0][0].isGiven)
        #expect(restored.difficulty == nil)
        #expect(restored.status == GameStatus.inProgress)
        #expect(restored.selectedCell == nil)
    }

    @Test func restoresACompletedSessionAndItsCompletionStatus() throws {
        var session = try GameSession()
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where session.puzzle.givens[row][column] == 0 {
                try session.setValue(session.puzzle.solution[row][column], row: row, column: column)
            }
        }

        let restored = try GameSession(snapshot: session.snapshot())
        #expect(restored.status == .completed)
        #expect(restored.board.isSolved)
    }

    @Test func rejectsUnsupportedVersionsAndMalformedState() throws {
        let session = try GameSession()
        let snapshot = session.snapshot()
        let unsupportedSnapshot = GameSessionSnapshot(
            version: GameSessionSnapshot.currentVersion + 1,
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: snapshot.values,
            difficulty: snapshot.difficulty,
            status: snapshot.status
        )
        #expect(throws: GameSessionSnapshotError.unsupportedVersion(2)) {
            try GameSession(snapshot: unsupportedSnapshot)
        }

        var alteredValues = snapshot.values
        alteredValues[0][0] = 4
        let alteredGivenSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: alteredValues,
            difficulty: snapshot.difficulty,
            status: snapshot.status
        )
        #expect(throws: GameSessionSnapshotError.modifiedGiven(row: 0, column: 0)) {
            try GameSession(snapshot: alteredGivenSnapshot)
        }

        let inconsistentStatusSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: snapshot.values,
            difficulty: snapshot.difficulty,
            status: .completed
        )
        #expect(throws: GameSessionSnapshotError.inconsistentStatus) {
            try GameSession(snapshot: inconsistentStatusSnapshot)
        }
    }

    @Test func rejectsSnapshotsWithConflictingEditableValues() throws {
        let snapshot = try GameSession().snapshot()
        var conflictingValues = snapshot.values
        conflictingValues[0][2] = 4
        conflictingValues[0][3] = 4
        let conflictingSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: conflictingValues,
            difficulty: snapshot.difficulty,
            status: snapshot.status
        )

        #expect(throws: GameSessionSnapshotError.conflictingValue(row: 0, column: 2)) {
            try GameSession(snapshot: conflictingSnapshot)
        }
    }
}
