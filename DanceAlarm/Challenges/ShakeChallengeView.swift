import SwiftUI
import CoreMotion

struct ShakeChallengeView: View {
    let onCompleted: () -> Void
    private let requiredShakes = 15
    @State private var shakeCount = 0
    private let motionManager = CMMotionManager()

    var body: some View {
        ChallengeScaffold(
            icon: "iphone.gen3.radiowaves.left.and.right",
            title: "Тряси телефон!",
            subtitle: "Потряси телефон \(requiredShakes) раз"
        ) {
            Text("\(shakeCount) / \(requiredShakes)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .onAppear(perform: start)
        .onDisappear { motionManager.stopAccelerometerUpdates() }
    }

    private func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 20.0
        var wasHigh = false
        motionManager.startAccelerometerUpdates(to: .main) { data, _ in
            guard let data else { return }
            let magnitude = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            if magnitude > 2.3 && !wasHigh {
                wasHigh = true
                shakeCount += 1
                if shakeCount >= requiredShakes {
                    motionManager.stopAccelerometerUpdates()
                    onCompleted()
                }
            } else if magnitude < 1.5 {
                wasHigh = false
            }
        }
    }
}
