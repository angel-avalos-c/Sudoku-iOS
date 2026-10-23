import Testing
@testable import SudokuCore

struct DifficultyClassifierTests {
    @Test func classifiesKnownEasyAndHardReferencePuzzles() throws {
        let easyAnalysis = try SudokuDifficultyClassifier.analyze(PuzzleCatalog.starter.givens)
        let hardAnalysis = try SudokuDifficultyClassifier.analyze(aiEscargot)

        #expect(easyAnalysis.difficulty == .easy)
        #expect(easyAnalysis.hiddenSinglePlacements == 0)
        #expect(easyAnalysis.backtrackingDecisions == 0)
        #expect(hardAnalysis.difficulty == .hard)
        #expect(hardAnalysis.backtrackingDecisions > 0)
    }

    @Test func classifiesKnownMediumReferencePuzzleUsingHiddenSingles() throws {
        let analysis = try SudokuDifficultyClassifier.analyze(mediumReference)

        #expect(analysis.difficulty == .medium)
        #expect(analysis.hiddenSinglePlacements > 0)
        #expect(analysis.backtrackingDecisions == 0)
    }

    @Test func rejectsPuzzlesThatAreNotUniquelySolvable() {
        let emptyGrid = Array(
            repeating: Array(repeating: 0, count: SudokuRules.gridSize),
            count: SudokuRules.gridSize
        )

        #expect(throws: SudokuDifficultyClassifierError.notUniquelySolvable(solutionCount: 2)) {
            _ = try SudokuDifficultyClassifier.classify(emptyGrid)
        }
    }

    @Test func rejectsUnsolvablePuzzles() {
        var unsolvableGrid = PuzzleCatalog.starter.givens
        unsolvableGrid[0][2] = 5

        #expect(throws: SudokuDifficultyClassifierError.notUniquelySolvable(solutionCount: 0)) {
            _ = try SudokuDifficultyClassifier.classify(unsolvableGrid)
        }
    }

    @Test func analysisIsDeterministic() throws {
        let firstAnalysis = try SudokuDifficultyClassifier.analyze(aiEscargot)
        let secondAnalysis = try SudokuDifficultyClassifier.analyze(aiEscargot)

        #expect(firstAnalysis == secondAnalysis)
    }

    @Test func hardReferenceRemainsHardAfterSpeculativeTechniquePropagation() throws {
        let analysis = try SudokuDifficultyClassifier.analyze(aiEscargot)

        #expect(analysis.difficulty == .hard)
        #expect(analysis.backtrackingDecisions > 0)
    }

    private let mediumReference = [
        [0, 2, 0, 8, 3, 0, 0, 6, 0],
        [0, 0, 0, 0, 0, 0, 0, 5, 7],
        [0, 1, 6, 0, 0, 7, 0, 0, 9],
        [0, 5, 0, 4, 0, 3, 6, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 2],
        [0, 6, 7, 9, 5, 0, 0, 0, 0],
        [0, 9, 0, 0, 4, 0, 0, 0, 0],
        [6, 0, 0, 0, 0, 0, 4, 1, 8],
        [0, 4, 0, 2, 0, 0, 0, 0, 5],
    ]

    private let aiEscargot = [
        [1, 0, 0, 0, 0, 7, 0, 9, 0],
        [0, 3, 0, 0, 2, 0, 0, 0, 8],
        [0, 0, 9, 6, 0, 0, 5, 0, 0],
        [0, 0, 5, 3, 0, 0, 9, 0, 0],
        [0, 1, 0, 0, 8, 0, 0, 0, 2],
        [6, 0, 0, 0, 0, 4, 0, 0, 0],
        [3, 0, 0, 0, 0, 0, 0, 1, 0],
        [0, 4, 0, 0, 0, 0, 0, 0, 7],
        [0, 0, 7, 0, 0, 0, 3, 0, 0],
    ]
}
