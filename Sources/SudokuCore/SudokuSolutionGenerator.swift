/// Generates randomized, complete Sudoku solution grids.
///
/// A seeded generator produces the same sequence of grids for the same seed.
/// Call ``generate(using:)`` when an application needs to provide its own
/// random number source.
public struct SudokuSolutionGenerator: Sendable {
    private var random: SeededRandomNumberGenerator

    /// Creates a generator using a nondeterministic seed for normal gameplay.
    public init() {
        self.init(seed: UInt64.random(in: UInt64.min...UInt64.max))
    }

    /// Creates a deterministic generator for reproducible puzzle generation.
    public init(seed: UInt64) {
        random = SeededRandomNumberGenerator(seed: seed)
    }

    /// Produces a valid, complete 9 by 9 Sudoku grid.
    public mutating func generate() -> [[Int]] {
        Self.generate(using: &random)
    }

    /// Produces a valid, complete grid using the supplied random source.
    ///
    /// Supplying the same source state produces the same grid, which allows
    /// callers to control reproducibility without sharing generator state.
    public static func generate<R: RandomNumberGenerator>(using random: inout R) -> [[Int]] {
        let digits = shuffled(Array(1...SudokuRules.gridSize), using: &random)
        let rows = groupedOrder(using: &random)
        let columns = groupedOrder(using: &random)

        return rows.map { row in
            columns.map { column in
                digits[(row * SudokuRules.boxSize + row / SudokuRules.boxSize + column) % SudokuRules.gridSize]
            }
        }
    }

    private static func groupedOrder<R: RandomNumberGenerator>(using random: inout R) -> [Int] {
        let groups = shuffled(Array(0..<SudokuRules.boxSize), using: &random)
        return groups.flatMap { group in
            shuffled(Array(0..<SudokuRules.boxSize), using: &random).map {
                group * SudokuRules.boxSize + $0
            }
        }
    }

    private static func shuffled<R: RandomNumberGenerator>(_ values: [Int], using random: inout R) -> [Int] {
        var values = values
        guard values.count > 1 else { return values }

        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let randomIndex = Int.random(in: 0...index, using: &random)
            values.swapAt(index, randomIndex)
        }
        return values
    }
}

struct SeededRandomNumberGenerator: Equatable, RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
