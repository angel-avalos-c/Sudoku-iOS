import Testing
@testable import SudokuCore

struct PuzzleGenerationTests {
    @Test func seededGeneratorsProduceReproducibleUniquePuzzles() throws {
        var firstGenerator = SudokuPuzzleGenerator(seed: 99)
        var secondGenerator = SudokuPuzzleGenerator(seed: 99)

        let firstPuzzle = try firstGenerator.generate()
        let secondPuzzle = try secondGenerator.generate()

        #expect(firstPuzzle == secondPuzzle)
        #expect(try SudokuRules.isSolved(firstPuzzle.solution))
        #expect(try SudokuSolutionCounter.countSolutions(in: firstPuzzle.givens) == 1)
        #expect(firstPuzzle.givens.joined().contains(0))
        assertGivensMatchSolution(firstPuzzle)
    }

    @Test func generatedPuzzlesRemainValidAndUniqueAcrossSeeds() throws {
        for seed in 0..<10 {
            var generator = SudokuPuzzleGenerator(seed: UInt64(seed))
            let puzzle = try generator.generate()

            #expect(try SudokuRules.isSolved(puzzle.solution))
            #expect(try SudokuSolutionCounter.countSolutions(in: puzzle.givens) == 1)
            assertGivensMatchSolution(puzzle)
        }
    }

    @Test func removalAttemptLimitBoundsGeneration() throws {
        var generator = SudokuPuzzleGenerator(seed: 7)
        let puzzle = try generator.generate(maximumRemovalAttempts: 1)

        #expect(puzzle.givens.joined().filter { $0 != 0 }.count == 80)
        #expect(try SudokuSolutionCounter.countSolutions(in: puzzle.givens) == 1)
    }

    @Test func rejectsInvalidRemovalAttemptLimit() {
        var generator = SudokuPuzzleGenerator(seed: 7)

        #expect(throws: SudokuPuzzleGeneratorError.invalidRemovalAttemptLimit(0)) {
            _ = try generator.generate(maximumRemovalAttempts: 0)
        }
    }

    @Test func seededDifficultyGenerationIsReproducibleAndCorrectlyClassified() throws {
        let references: [(difficulty: SudokuDifficulty, seed: UInt64)] = [
            (.easy, 0),
            (.medium, 0),
            (.hard, 2),
        ]

        for reference in references {
            var firstGenerator = SudokuPuzzleGenerator(seed: reference.seed)
            var secondGenerator = SudokuPuzzleGenerator(seed: reference.seed)

            let firstPuzzle = try firstGenerator.generate(
                difficulty: reference.difficulty,
                maximumGenerationAttempts: 1
            )
            let secondPuzzle = try secondGenerator.generate(
                difficulty: reference.difficulty,
                maximumGenerationAttempts: 1
            )

            #expect(firstPuzzle == secondPuzzle)
            #expect(try SudokuDifficultyClassifier.classify(firstPuzzle.givens) == reference.difficulty)
            #expect(try SudokuSolutionCounter.countSolutions(in: firstPuzzle.givens) == 1)
            assertGivensMatchSolution(firstPuzzle)
        }
    }

    @Test func requestedDifficultyGenerationFailsExplicitlyWithinAConstrainedBudget() {
        var generator = SudokuPuzzleGenerator(seed: 0)

        #expect(throws: SudokuPuzzleGeneratorError.unableToGenerateDifficulty(.hard, attempts: 1)) {
            _ = try generator.generate(difficulty: .hard, maximumGenerationAttempts: 1)
        }
    }

    @Test func rejectsInvalidGenerationAttemptLimit() {
        var generator = SudokuPuzzleGenerator(seed: 0)

        #expect(throws: SudokuPuzzleGeneratorError.invalidGenerationAttemptLimit(0)) {
            _ = try generator.generate(difficulty: .easy, maximumGenerationAttempts: 0)
        }
    }

    private func assertGivensMatchSolution(_ puzzle: Puzzle) {
        for row in 0..<SudokuRules.gridSize {
            for column in 0..<SudokuRules.gridSize where puzzle.givens[row][column] != 0 {
                #expect(puzzle.givens[row][column] == puzzle.solution[row][column])
            }
        }
    }
}
