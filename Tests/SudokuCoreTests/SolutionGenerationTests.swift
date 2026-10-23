import Testing
@testable import SudokuCore

struct SolutionGenerationTests {
    @Test func seededGeneratorsProduceReproducibleValidSolutions() throws {
        var firstGenerator = SudokuSolutionGenerator(seed: 42)
        var secondGenerator = SudokuSolutionGenerator(seed: 42)

        let firstSolution = firstGenerator.generate()
        let secondSolution = secondGenerator.generate()

        #expect(firstSolution == secondSolution)
        #expect(try SudokuRules.isSolved(firstSolution))
        #expect(try SudokuSolutionCounter.countSolutions(in: firstSolution) == 1)
        #expect(try SudokuRules.isSolved(firstGenerator.generate()))
    }

    @Test func generatedSolutionsAreValidAcrossOneHundredDeterministicSeeds() throws {
        for seed in 0..<100 {
            var generator = SudokuSolutionGenerator(seed: UInt64(seed))
            #expect(try SudokuRules.isSolved(generator.generate()))
        }
    }

    @Test func differentSeedsProduceMoreThanOneCompletedSolution() {
        var solutions = Set<[[Int]]>()

        for seed in 0..<100 {
            var generator = SudokuSolutionGenerator(seed: UInt64(seed))
            solutions.insert(generator.generate())
        }

        #expect(solutions.count > 1)
    }

    @Test func injectedRandomSourceProducesAValidSolution() throws {
        var random = TestRandomNumberGenerator()

        let solution = SudokuSolutionGenerator.generate(using: &random)

        #expect(try SudokuRules.isSolved(solution))
    }

    @Test func countsUniqueAndMultipleSolutionsWithABound() throws {
        #expect(try SudokuSolutionCounter.countSolutions(in: PuzzleCatalog.starter.givens) == 1)

        let emptyGrid = Array(
            repeating: Array(repeating: 0, count: SudokuRules.gridSize),
            count: SudokuRules.gridSize
        )
        #expect(try SudokuSolutionCounter.countSolutions(in: emptyGrid) == 2)
        #expect(try SudokuSolutionCounter.countSolutions(in: emptyGrid, upTo: 1) == 1)
    }

    @Test func returnsZeroForConflictingGivensAndValidatesInputs() throws {
        var conflictingGrid = PuzzleCatalog.starter.givens
        conflictingGrid[0][2] = 5
        #expect(try SudokuSolutionCounter.countSolutions(in: conflictingGrid) == 0)

        let malformedGrid = Array(repeating: Array(repeating: 0, count: 9), count: 8)
        #expect(throws: SudokuBoardError.invalidDimensions) {
            _ = try SudokuSolutionCounter.countSolutions(in: malformedGrid)
        }
        var invalidValueGrid = PuzzleCatalog.starter.givens
        invalidValueGrid[0][2] = 10
        #expect(throws: SudokuBoardError.invalidCellValue(10)) {
            _ = try SudokuSolutionCounter.countSolutions(in: invalidValueGrid)
        }
        #expect(throws: SudokuSolutionCounterError.invalidLimit(0)) {
            _ = try SudokuSolutionCounter.countSolutions(in: PuzzleCatalog.starter.givens, upTo: 0)
        }
    }
}

private struct TestRandomNumberGenerator: RandomNumberGenerator {
    private var value: UInt64 = 0

    mutating func next() -> UInt64 {
        defer { value &+= 1 }
        return value
    }
}
