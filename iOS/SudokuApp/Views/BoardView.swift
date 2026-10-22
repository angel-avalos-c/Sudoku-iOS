import SudokuCore
import SwiftUI

struct BoardView: View {
    let board: Board
    let selectedCell: CellCoordinate?
    let onCellTap: (Int, Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: SudokuRules.gridSize)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<SudokuRules.gridSize, id: \.self) { row in
                ForEach(0..<SudokuRules.gridSize, id: \.self) { column in
                    CellView(
                        cell: board.cells[row][column],
                        row: row,
                        column: column,
                        isSelected: selectedCell == CellCoordinate(row: row, column: column),
                        action: { onCellTap(row, column) }
                    )
                }
            }
        }
        .overlay(Rectangle().stroke(.primary, lineWidth: 2))
        .accessibilityIdentifier("sudoku.board")
    }
}
