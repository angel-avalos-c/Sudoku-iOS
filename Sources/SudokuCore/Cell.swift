/// A single Sudoku cell.
///
/// `value` uses the range `0...9`, where `0` represents an empty cell.
/// Cells marked as givens cannot be changed through `Board`.
public struct Cell: Equatable, Sendable {
    public private(set) var value: Int
    public let isGiven: Bool

    /// Creates a cell with a value in the inclusive range `0...9`.
    ///
    /// - Throws: `SudokuBoardError.invalidCellValue` when `value` is outside
    ///   the supported range, or `SudokuBoardError.emptyGivenCell` when a
    ///   given is initialized with the empty value (`0`).
    public init(value: Int, isGiven: Bool) throws {
        guard Self.validValues.contains(value) else {
            throw SudokuBoardError.invalidCellValue(value)
        }
        guard !isGiven || value != 0 else {
            throw SudokuBoardError.emptyGivenCell
        }

        self.value = value
        self.isGiven = isGiven
    }

    public var isEditable: Bool {
        !isGiven
    }

    mutating func setValue(_ value: Int) {
        self.value = value
    }

    private static let validValues = 0...9
}
