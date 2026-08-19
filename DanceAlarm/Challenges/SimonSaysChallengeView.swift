import SwiftUI

struct SimonSaysChallengeView: View {
    let onCompleted: () -> Void
    private let colors: [Color] = [.red, .green, .blue, .yellow]
    private let sequenceLength = 4 // было 5 — сделали чуть проще

    @State private var sequence: [Int] = []
    @State private var userInput: [Int] = []
    @State private var isShowingSequence = true
    @State private var highlightedIndex: Int? = nil       // подсветка во время показа последовательности
    @State private var tappedIndex: Int? = nil             // подсветка когда САМ пользователь нажал
    @State private var tappedIsWrong = false
    @State private var statusText = "Запоминай..."

    var body: some View {
        ChallengeScaffold(
            icon: "square.grid.2x2.fill",
            title: "Simon Says",
            subtitle: statusText
        ) {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<colors.count, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tappedIndex == idx ? (tappedIsWrong ? Color.red : Color.white) : colors[idx])
                            .opacity(highlightedIndex == idx ? 1.0 : (tappedIndex == idx ? 1.0 : 0.5))
                            .frame(width: 100, height: 100)
                            .scaleEffect(highlightedIndex == idx || tappedIndex == idx ? 1.08 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: tappedIndex)
                            .animation(.easeOut(duration: 0.15), value: highlightedIndex)
                            .onTapGesture { tap(idx) }
                            .disabled(isShowingSequence)
                    }
                }
                if !isShowingSequence {
                    Button {
                        playSequence()
                    } label: {
                        Label("Показать ещё раз", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                highlightedIndex = idx
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    highlightedIndex = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sequence.count) * 0.8) {
            isShowingSequence = false
            statusText = "Теперь повтори! (\(userInput.count)/\(sequence.count))"
        }
    }

    private func tap(_ idx: Int) {
        let position = userInput.count
        let isCorrect = sequence[position] == idx

        tappedIsWrong = !isCorrect
        tappedIndex = idx
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            tappedIndex = nil
        }

        if !isCorrect {
            statusText = "Ошибка, начинаем заново"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { newGame() }
            return
        }

        userInput.append(idx)
        if userInput.count == sequence.count {
            statusText = "Отлично! ✅"
            onCompleted()
        } else {
            statusText = "Повтори! (\(userInput.count)/\(sequence.count))"
        }
    }
}
