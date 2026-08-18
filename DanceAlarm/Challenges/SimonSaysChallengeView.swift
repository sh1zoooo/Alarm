import SwiftUI

struct SimonSaysChallengeView: View {
    let onCompleted: () -> Void
    private let colors: [Color] = [.red, .green, .blue, .yellow]
    private let sequenceLength = 5

    @State private var sequence: [Int] = []
    @State private var userInput: [Int] = []
    @State private var isShowingSequence = true
    @State private var highlightedIndex: Int? = nil
    @State private var statusText = "Запоминай..."

    var body: some View {
        ChallengeScaffold(
            icon: "square.grid.2x2.fill",
            title: "Simon Says",
            subtitle: statusText
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<colors.count, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colors[idx])
                        .opacity(highlightedIndex == idx ? 1.0 : 0.5)
                        .frame(width: 100, height: 100)
                        .onTapGesture { tap(idx) }
                        .disabled(isShowingSequence)
                }
            }
        }
        .onAppear(perform: newGame)
    }

    private func newGame() {
        sequence = (0..<sequenceLength).map { _ in Int.random(in: 0..<colors.count) }
        userInput = []
        playSequence()
    }

    private func playSequence() {
        isShowingSequence = true
        statusText = "Запоминай..."
        for (i, idx) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                highlightedIndex = idx
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    highlightedIndex = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sequence.count) * 0.7) {
            isShowingSequence = false
            statusText = "Теперь повтори!"
        }
    }

    private func tap(_ idx: Int) {
        userInput.append(idx)
        let position = userInput.count - 1
        if userInput[position] != sequence[position] {
            statusText = "Ошибка, начинаем заново"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { newGame() }
            return
        }
        if userInput.count == sequence.count {
            statusText = "Отлично! ✅"
            onCompleted()
        }
    }
}
