/// Errors returned by the unique Sudoku puzzle generator.
public enum SudokuPuzzleGeneratorError: Error, Equatable, Sendable {
    case invalidRemovalAttemptLimit(Int)
    case invalidGenerationAttemptLimit(Int)
    case unableToGenerateDifficulty(SudokuDifficulty, attempts: Int)
}

/// Generates playable Sudoku puzzles with a single solution.
///
/// This generator does not assign a difficulty. Difficulty classification and
/// selection are deliberately separate concerns.
public struct SudokuPuzzleGenerator: Equatable, Sendable {
    private var random: SeededRandomNumberGenerator

    /// Creates a generator using a nondeterministic seed for normal gameplay.
    public init() {
        self.init(seed: UInt64.random(in: UInt64.min...UInt64.max))
    }

    /// Creates a deterministic generator for reproducible puzzle generation.
    public init(seed: UInt64) {
        random = SeededRandomNumberGenerator(seed: seed)
    }

    /// Generates a puzzle by attempting up to 40 clue removals.
    ///
    /// Each accepted removal preserves exactly one solution. The removal
    /// budget bounds this operation independently of any future difficulty
    /// classification policy.
    public mutating func generate(maximumRemovalAttempts: Int = 40) throws -> Puzzle {
        try Self.generate(using: &random, maximumRemovalAttempts: maximumRemovalAttempts)
    }

    /// Generates a uniquely solvable puzzle classified at the requested difficulty.
    ///
    /// Clue-removal budgets are only search heuristics. The generated puzzle is
    /// accepted solely when `SudokuDifficultyClassifier` returns the requested
    /// difficulty, so clue count never assigns a label by itself.
    ///
    /// - Throws: `SudokuPuzzleGeneratorError.invalidGenerationAttemptLimit` for
    ///   a nonpositive budget, or
    ///   `SudokuPuzzleGeneratorError.unableToGenerateDifficulty` when no
    ///   matching puzzle is found within the budget.
    public mutating func generate(
        difficulty: SudokuDifficulty,
        maximumGenerationAttempts: Int = 12
    ) throws -> Puzzle {
        try Self.generate(
            difficulty: difficulty,
            using: &random,
            maximumGenerationAttempts: maximumGenerationAttempts
        )
    }

    /// Generates a puzzle using the supplied random source.
    ///
    /// Providing the same source state yields the same generated puzzle.
    public static func generate<R: RandomNumberGenerator>(
        using random: inout R,
        maximumRemovalAttempts: Int = 40
    ) throws -> Puzzle {
        guard maximumRemovalAttempts > 0 else {
            throw SudokuPuzzleGeneratorError.invalidRemovalAttemptLimit(maximumRemovalAttempts)
        }

        let solution = SudokuSolutionGenerator.generate(using: &random)
        var givens = solution
        let coordinates = shuffledCoordinates(using: &random)

        for (row, column) in coordinates.prefix(maximumRemovalAttempts) {
            let value = givens[row][column]
            givens[row][column] = 0

            if try SudokuSolutionCounter.countSolutions(in: givens) != 1 {
                givens[row][column] = value
            }
        }

        return try Puzzle(givens: givens, solution: solution)
    }

    /// Generates a requested difficulty using the supplied random source.
    ///
    /// Equal source state and difficulty yield equal results when a matching
    /// puzzle is found within the same generation-attempt budget.
    public static func generate<R: RandomNumberGenerator>(
        difficulty: SudokuDifficulty,
        using random: inout R,
        maximumGenerationAttempts: Int = 12
    ) throws -> Puzzle {
        guard maximumGenerationAttempts > 0 else {
            throw SudokuPuzzleGeneratorError.invalidGenerationAttemptLimit(maximumGenerationAttempts)
        }

        let removalAttemptLimit = removalAttemptLimit(for: difficulty)
        for _ in 0..<maximumGenerationAttempts {
            let puzzle = try generate(
                using: &random,
                maximumRemovalAttempts: removalAttemptLimit
            )
            if try SudokuDifficultyClassifier.classify(puzzle.givens) == difficulty {
                return puzzle
            }
        }

        throw SudokuPuzzleGeneratorError.unableToGenerateDifficulty(
            difficulty,
            attempts: maximumGenerationAttempts
        )
    }

    private static func removalAttemptLimit(for difficulty: SudokuDifficulty) -> Int {
        switch difficulty {
        case .easy:
            return 40
        case .medium:
            return 50
        case .hard:
            return 60
        }
    }

    private static func shuffledCoordinates<R: RandomNumberGenerator>(using random: inout R) -> [(Int, Int)] {
        var indices = Array(0..<(SudokuRules.gridSize * SudokuRules.gridSize))

        for index in stride(from: indices.count - 1, through: 1, by: -1) {
            let randomIndex = Int.random(in: 0...index, using: &random)
            indices.swapAt(index, randomIndex)
        }

        return indices.map { index in
            (index / SudokuRules.gridSize, index % SudokuRules.gridSize)
        }
    }
}
