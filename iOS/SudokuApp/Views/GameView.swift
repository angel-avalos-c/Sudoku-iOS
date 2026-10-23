import SudokuCore
import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel

    init(viewModel: GameViewModel = GameViewModel(difficulty: .easy)) {
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
                .disabled(viewModel.isGenerating)

                VStack(spacing: 8) {
                    Text("Next Game Difficulty")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 8) {
                        ForEach(SudokuDifficulty.allCases, id: \.rawValue) { difficulty in
                            Button(difficulty.rawValue.capitalized) {
                                viewModel.selectDifficulty(difficulty)
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.selectedDifficulty == difficulty ? .accentColor : .secondary)
                            .accessibilityIdentifier("sudoku.difficulty.\(difficulty.rawValue)")
                        }
                    }
                }
                .disabled(viewModel.isGenerating)

                if viewModel.isGenerating {
                    ProgressView("Generating puzzle...")
                        .accessibilityIdentifier("sudoku.generating")
                }

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
                .disabled(viewModel.isGenerating)

                HStack {
                    Button("Reset", action: viewModel.reset)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("sudoku.reset")

                    Button("New Game", action: viewModel.newGame)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("sudoku.newGame")
                }
                .disabled(viewModel.isGenerating)
            }
            .padding()
            .frame(maxWidth: 600)
        }
    }
}

#Preview {
    GameView()
}
