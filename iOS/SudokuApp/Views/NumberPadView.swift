import SwiftUI

struct NumberPadView: View {
    let onNumber: (Int) -> Void
    let onClear: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { value in
                Button("\(value)") { onNumber(value) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("sudoku.keypad.\(value)")
            }

            Button("Clear", action: onClear)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
                .gridCellColumns(3)
                .accessibilityIdentifier("sudoku.clear")
        }
    }
}
