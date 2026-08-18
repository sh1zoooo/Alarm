import SwiftUI
import CoreMotion

struct StepsChallengeView: View {
    let onCompleted: () -> Void
    private let requiredSteps = 20
    @State private var steps = 0
    private let pedometer = CMPedometer()

    var body: some View {
        ChallengeScaffold(
            icon: "figure.walk",
            title: "Пройди шаги",
            subtitle: "Пройди \(requiredSteps) шагов с телефоном в руке"
        ) {
            Text("\(steps) / \(requiredSteps)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .onAppear(perform: start)
        .onDisappear { pedometer.stopUpdates() }
    }

    private func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { data, _ in
            guard let data else { return }
            DispatchQueue.main.async {
                steps = data.numberOfSteps.intValue
                if steps >= requiredSteps {
                    pedometer.stopUpdates()
                    onCompleted()
                }
            }
        }
    }
}
