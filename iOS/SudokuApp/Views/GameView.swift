import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel

    init(viewModel: GameViewModel = GameViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Sudoku")
                    .font(.largeTitle.bold())

                BoardView(
                    board: viewModel.board,
                    selectedCell: viewModel.selectedCell,
                    onCellTap: viewModel.selectCell(row:column:)
                )
                .frame(maxWidth: 520)
                .aspectRatio(1, contentMode: .fit)

                if let feedback = viewModel.feedback {
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(feedback)
                }

                if viewModel.status == .completed {
                    Text("Puzzle complete!")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("sudoku.completed")
                }

                NumberPadView(
                    onNumber: viewModel.enter(_:),
                    onClear: viewModel.clearSelectedCell
                )
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)

                Button("New Game", action: viewModel.newGame)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("sudoku.newGame")
            }
            .padding()
            .frame(maxWidth: 600)
        }
    }
}

#Preview {
    GameView()
}
