import SudokuCore
import SwiftUI

struct RootView: View {
    private let puzzle = PuzzleCatalog.starter

    var body: some View {
        VStack(spacing: 12) {
            Text("Sudoku")
                .font(.largeTitle)
            Text("Core ready: \(puzzle.givens.count)x\(puzzle.givens.count) puzzle")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
