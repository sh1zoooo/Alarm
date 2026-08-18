import SwiftUI

struct MathChallengeView: View {
    let onCompleted: () -> Void
    private let requiredCorrect = 3

    @State private var solved = 0
    @State private var a = 0
    @State private var b = 0
    @State private var op = "+"
    @State private var answer = ""
    @State private var isWrong = false

    var body: some View {
        ChallengeScaffold(
            icon: "function",
            title: "Реши пример",
            subtitle: "Реши \(requiredCorrect) примеров подряд, чтобы выключить будильник (\(solved)/\(requiredCorrect))"
        ) {
            VStack(spacing: 20) {
                Text("\(a) \(op) \(b) = ?")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                TextField("Ответ", text: $answer)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .frame(width: 160)
                if isWrong {
                    Text("Неверно, попробуй ещё раз")
                        .foregroundColor(.red)
                }
                Button("Проверить") { check() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
            }
        }
        .onAppear(perform: newProblem)
    }

    private func newProblem() {
        op = ["+", "-", "×"].randomElement()!
        switch op {
        case "+": a = Int.random(in: 10...50); b = Int.random(in: 10...50)
        case "-": a = Int.random(in: 20...60); b = Int.random(in: 1...a)
        default: a = Int.random(in: 2...12); b = Int.random(in: 2...12)
        }
        answer = ""
        isWrong = false
    }

    private func correctAnswer() -> Int {
        switch op {
        case "+": return a + b
        case "-": return a - b
        default: return a * b
        }
    }

    private func check() {
        if Int(answer.trimmingCharacters(in: .whitespaces)) == correctAnswer() {
            solved += 1
            if solved >= requiredCorrect {
                onCompleted()
            } else {
                newProblem()
            }
        } else {
            isWrong = true
        }
    }
}
