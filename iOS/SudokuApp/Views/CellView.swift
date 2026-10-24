import SudokuCore
import SwiftUI

struct CellView: View {
    let cell: Cell
    let notes: Set<Int>
    let row: Int
    let column: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if cell.value == 0 {
                    candidateNotes
                } else {
                    Text("\(cell.value)")
                        .font(.title2.weight(cell.isGiven ? .bold : .regular))
                        .foregroundStyle(cell.isGiven ? Color.primary : Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isGiven)
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .top) {
            if row.isMultiple(of: SudokuRules.boxSize) {
                Rectangle().fill(.primary).frame(height: 2)
            }
        }
        .overlay(alignment: .leading) {
            if column.isMultiple(of: SudokuRules.boxSize) {
                Rectangle().fill(.primary).frame(width: 2)
            }
        }
        .overlay(alignment: .bottom) {
            if row == SudokuRules.gridSize - 1 {
                Rectangle().fill(.primary).frame(height: 2)
            } else {
                Rectangle().fill(.secondary.opacity(0.4)).frame(height: 0.5)
            }
        }
        .overlay(alignment: .trailing) {
            if column == SudokuRules.gridSize - 1 {
                Rectangle().fill(.primary).frame(width: 2)
            } else {
                Rectangle().fill(.secondary.opacity(0.4)).frame(width: 0.5)
            }
        }
        .accessibilityIdentifier("sudoku.cell.\(row).\(column)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
    }

    private var accessibilityLabel: String {
        let kind = cell.isGiven ? "given" : "editable"
        let value = cell.value == 0 ? "empty" : "\(cell.value)"
        let noteDescription = notes.isEmpty ? "" : ", notes \(notes.sorted().map(String.init).joined(separator: ", "))"
        return "Row \(row + 1), column \(column + 1), \(kind), \(value)\(noteDescription)"
    }

    private var candidateNotes: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let candidate = row * 3 + column
                        Text(notes.contains(candidate) ? "\(candidate)" : "")
                            .font(.caption2)
                            .foregroundStyle(Color.blue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(2)
    }
}
