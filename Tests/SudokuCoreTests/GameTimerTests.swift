import Testing
@testable import SudokuCore

struct GameTimerTests {
    @Test func accumulatesOnlyExplicitActiveIntervals() {
        var timer = GameTimer()
        timer.resume(at: 10)
        timer.update(at: 15)
        timer.pause(at: 18)
        timer.update(at: 100)
        timer.resume(at: 120)
        timer.update(at: 125)

        #expect(timer.elapsedSeconds == 13)
        #expect(timer.isRunning)
    }

    @Test func completionFreezesElapsedTimeAndSnapshotsPersistIt() throws {
        var session = try GameSession()
        session.resumeTimer(at: 0)
        session.updateTimer(at: 12)
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where session.puzzle.givens[row][column] == 0 {
                if row == 8, column == 6 {
                    try session.setValue(
                        session.puzzle.solution[row][column],
                        row: row,
                        column: column,
                        completionTimestamp: 15
                    )
                } else {
                    try session.setValue(session.puzzle.solution[row][column], row: row, column: column)
                }
            }
        }
        session.updateTimer(at: 50)

        #expect(session.status == .completed)
        #expect(session.elapsedSeconds == 15)
        let restored = try GameSession(snapshot: session.snapshot())
        #expect(restored.elapsedSeconds == 15)
    }

    @Test func resetAndNewGameStartFreshTimers() throws {
        var session = try GameSession(difficulty: .easy, seed: 42)
        session.resumeTimer(at: 0)
        session.updateTimer(at: 8)
        try session.reset()
        #expect(session.elapsedSeconds == 0)

        session.resumeTimer(at: 10)
        session.updateTimer(at: 13)
        try session.newGame(difficulty: .medium)
        #expect(session.elapsedSeconds == 0)
    }
}
