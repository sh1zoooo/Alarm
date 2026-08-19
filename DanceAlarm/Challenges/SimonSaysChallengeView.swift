import SwiftUI

/// Многоэтапный Simon Says: раунд 1 — 2 цвета, раунд 2 — 3 цвета, раунд 3 — 4 цвета.
/// Перед каждым показом есть пауза "Приготовься", чтобы не начиналось внезапно.
struct SimonSaysChallengeView: View {
    let onCompleted: () -> Void
    private let colors: [Color] = [.red, .green, .blue, .yellow]
    private let stageLengths = [2, 3, 4] // три этапа возрастающей сложности

    @State private var stageIndex = 0
    @State private var sequence: [Int] = []
    @State private var userInput: [Int] = []
    @State private var isShowingSequence = true
    @State private var isPreparing = true
    @State private var highlightedIndex: Int? = nil
    @State private var tappedIndex: Int? = nil
    @State private var tappedIsWrong = false
    @State private var statusText = "Приготовься..."

    var body: some View {
        ChallengeScaffold(
            icon: "square.grid.2x2.fill",
            title: "Simon Says — этап \(stageIndex + 1)/\(stageLengths.count)",
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
                            .disabled(isShowingSequence || isPreparing)
                    }
                }
                if !isShowingSequence && !isPreparing {
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
        .onAppear { startStage(0) }
    }

    private func startStage(_ index: Int) {
        stageIndex = index
        sequence = (0..<stageLengths[index]).map { _ in Int.random(in: 0..<colors.count) }
        userInput = []
        isPreparing = true
        statusText = "Приготовься..."
        // Пауза перед показом — чтобы игрок успел сфокусироваться на экране
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isPreparing = false
            playSequence()
        }
    }

    private func playSequence() {
        isShowingSequence = true
        statusText = "Запоминай..."
        let interval = 1.0   // время между началами вспышек — с запасом на реакцию глаз
        let flashDuration = 0.55
        for (i, idx) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                highlightedIndex = idx
                DispatchQueue.main.asyncAfter(deadline: .now() + flashDuration) {
                    highlightedIndex = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(sequence.count) * interval) {
            isShowingSequence = false
            statusText = "Повтори! (\(userInput.count)/\(sequence.count))"
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
            statusText = "Ошибка, начинаем этап заново"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { startStage(stageIndex) }
            return
        }

        userInput.append(idx)
        if userInput.count == sequence.count {
            if stageIndex == stageLengths.count - 1 {
                statusText = "Все этапы пройдены! ✅"
                onCompleted()
            } else {
                statusText = "Этап пройден! Следующий..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { startStage(stageIndex + 1) }
            }
        } else {
            statusText = "Повтори! (\(userInput.count)/\(sequence.count))"
        }
    }
}
