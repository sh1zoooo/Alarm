import SwiftUI

struct TypingChallengeView: View {
    let onCompleted: () -> Void
    private let phrases = [
        "Просыпайся и двигайся вперёд",
        "Сегодня будет отличный день",
        "Я встаю с кровати прямо сейчас",
        "Будильник побеждён, пора вставать",
        "Хватит спать, начинаем действовать"
    ]
    @State private var targetPhrase = ""
    @State private var input = ""

    var body: some View {
        ChallengeScaffold(
            icon: "keyboard",
            title: "Напечатай фразу",
            subtitle: "Напечатай точно как написано, без ошибок"
        ) {
            VStack(spacing: 16) {
                Text(targetPhrase)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                TextField("Печатай здесь", text: $input)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .onChange(of: input) { newValue in
                        if newValue == targetPhrase {
                            onCompleted()
                        }
                    }
            }
        }
        .onAppear {
            targetPhrase = phrases.randomElement()!
        }
    }
}
