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
        #expect(throws: GameSessionSnapshotError.unsupportedVersion(5)) {
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

    @Test func migratesPriorSnapshotVersionsAndRequiresCurrentTimerData() throws {
        var session = try GameSession()
        try session.toggleNote(1, row: 0, column: 2)
        try session.toggleNote(9, row: 0, column: 2)

        let restored = try GameSession(snapshot: session.snapshot())
        #expect(restored.notes[0][2] == [1, 9])

        let encodedSnapshot = try JSONEncoder().encode(session.snapshot())
        var legacyPayload = try #require(
            JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any]
        )
        legacyPayload["version"] = 1
        legacyPayload.removeValue(forKey: "notes")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)
        let legacySnapshot = try JSONDecoder().decode(GameSessionSnapshot.self, from: legacyData)
        let migrated = try GameSession(snapshot: legacySnapshot)
        #expect(migrated.notes.allSatisfy { $0.allSatisfy(\.isEmpty) })

        var versionTwoPayload = try #require(
            JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any]
        )
        versionTwoPayload["version"] = 2
        versionTwoPayload.removeValue(forKey: "hintsUsed")
        let versionTwoData = try JSONSerialization.data(withJSONObject: versionTwoPayload)
        let migratedVersionTwoSnapshot = try JSONDecoder().decode(GameSessionSnapshot.self, from: versionTwoData)
        #expect(try GameSession(snapshot: migratedVersionTwoSnapshot).hintsUsed == 0)
        #expect(try GameSession(snapshot: migratedVersionTwoSnapshot).elapsedSeconds == 0)

        versionTwoPayload.removeValue(forKey: "notes")
        let missingVersionTwoNotesData = try JSONSerialization.data(withJSONObject: versionTwoPayload)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GameSessionSnapshot.self, from: missingVersionTwoNotesData)
        }

        var versionThreePayload = try #require(
            JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any]
        )
        versionThreePayload["version"] = 3
        versionThreePayload.removeValue(forKey: "elapsedSeconds")
        let versionThreeData = try JSONSerialization.data(withJSONObject: versionThreePayload)
        let migratedVersionThreeSnapshot = try JSONDecoder().decode(GameSessionSnapshot.self, from: versionThreeData)
        #expect(try GameSession(snapshot: migratedVersionThreeSnapshot).elapsedSeconds == 0)

        versionThreePayload.removeValue(forKey: "hintsUsed")
        let missingVersionThreeHintsData = try JSONSerialization.data(withJSONObject: versionThreePayload)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GameSessionSnapshot.self, from: missingVersionThreeHintsData)
        }

        var versionFourPayload = try #require(
            JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any]
        )
        versionFourPayload.removeValue(forKey: "elapsedSeconds")
        let missingVersionFourTimerData = try JSONSerialization.data(withJSONObject: versionFourPayload)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GameSessionSnapshot.self, from: missingVersionFourTimerData)
        }
    }

    @Test func rejectsInvalidPersistedNotes() throws {
        let snapshot = try GameSession().snapshot()

        var invalidCandidateNotes = snapshot.notes
        invalidCandidateNotes[0][2] = [0]
        #expect(throws: GameSessionSnapshotError.invalidNotes) {
            try GameSession(snapshot: snapshotWith(notes: invalidCandidateNotes, from: snapshot))
        }

        var duplicateCandidateNotes = snapshot.notes
        duplicateCandidateNotes[0][2] = [1, 1]
        #expect(throws: GameSessionSnapshotError.invalidNotes) {
            try GameSession(snapshot: snapshotWith(notes: duplicateCandidateNotes, from: snapshot))
        }

        var incorrectlySizedNotes = snapshot.notes
        incorrectlySizedNotes.removeLast()
        #expect(throws: GameSessionSnapshotError.invalidNotes) {
            try GameSession(snapshot: snapshotWith(notes: incorrectlySizedNotes, from: snapshot))
        }

        var notesOnFixedCell = snapshot.notes
        notesOnFixedCell[0][0] = [1]
        #expect(throws: GameSessionSnapshotError.invalidNotes) {
            try GameSession(snapshot: snapshotWith(notes: notesOnFixedCell, from: snapshot))
        }

        var valuesWithEntry = snapshot.values
        valuesWithEntry[0][2] = 4
        var notesOnFilledCell = snapshot.notes
        notesOnFilledCell[0][2] = [1]
        let filledCellSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: valuesWithEntry,
            difficulty: snapshot.difficulty,
            status: snapshot.status,
            notes: notesOnFilledCell
        )
        #expect(throws: GameSessionSnapshotError.invalidNotes) {
            try GameSession(snapshot: filledCellSnapshot)
        }

        let negativeHintsSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: snapshot.values,
            difficulty: snapshot.difficulty,
            status: snapshot.status,
            notes: snapshot.notes,
            hintsUsed: -1
        )
        #expect(throws: GameSessionSnapshotError.invalidHintsUsed) {
            try GameSession(snapshot: negativeHintsSnapshot)
        }

        let negativeElapsedSnapshot = GameSessionSnapshot(
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: snapshot.values,
            difficulty: snapshot.difficulty,
            status: snapshot.status,
            notes: snapshot.notes,
            hintsUsed: snapshot.hintsUsed,
            elapsedSeconds: -1
        )
        #expect(throws: GameSessionSnapshotError.invalidElapsedSeconds) {
            try GameSession(snapshot: negativeElapsedSnapshot)
        }
    }

    private func snapshotWith(notes: [[[Int]]], from snapshot: GameSessionSnapshot) -> GameSessionSnapshot {
        GameSessionSnapshot(
            version: snapshot.version,
            givens: snapshot.givens,
            solution: snapshot.solution,
            values: snapshot.values,
            difficulty: snapshot.difficulty,
            status: snapshot.status,
            notes: notes,
            hintsUsed: snapshot.hintsUsed
        )
    }
}
