import SwiftUI
import CoreMotion

/// Нужно активно двигаться (танцевать) REQUIRED_SECONDS секунд подряд.
/// Если движение прекращается — таймер сбрасывается, чтобы нельзя было "накопить" рывками.
struct DanceChallengeView: View {
    let onCompleted: () -> Void
    private let requiredSeconds: Double = 8.0
    private let motionThreshold: Double = 1.3 // порог "резкого" ускорения (в g)

    @StateObject private var tracker = DanceMotionTracker()

    var body: some View {
        ChallengeScaffold(
            icon: "figure.dance",
            title: "Танцуй!",
            subtitle: "Активно двигайся \(Int(requiredSeconds)) секунд без остановки, чтобы выключить будильник"
        ) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 180, height: 180)
                    Circle()
                        .trim(from: 0, to: tracker.progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: tracker.progress)
                    Text("\(Int(tracker.progress * requiredSeconds))s / \(Int(requiredSeconds))s")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                Text(tracker.isMoving ? "🔥 Так держать!" : "Двигайся активнее!")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
        .onAppear {
            tracker.threshold = motionThreshold
            tracker.requiredSeconds = requiredSeconds
            tracker.onCompleted = onCompleted
            tracker.start()
        }
        .onDisappear {
            tracker.stop()
        }
    }
}

final class DanceMotionTracker: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var progress: Double = 0
    @Published var isMoving: Bool = false

    var threshold: Double = 1.3
    var requiredSeconds: Double = 8.0
    var onCompleted: (() -> Void)?

    private var accumulatedTime: Double = 0
    private var lastUpdate: Date?

    func start() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
        lastUpdate = Date()
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let magnitude = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            let deviation = abs(magnitude - 1.0) // 1g — гравитация в покое
            let now = Date()
            let dt = now.timeIntervalSince(self.lastUpdate ?? now)
            self.lastUpdate = now

            if deviation > (self.threshold - 1.0) {
                self.isMoving = true
                self.accumulatedTime += dt
            } else {
                self.isMoving = false
                // мягкий откат, а не полный сброс — чтобы короткие паузы между движениями не обнуляли всё
                self.accumulatedTime = max(0, self.accumulatedTime - dt * 2)
            }

            self.progress = min(1.0, self.accumulatedTime / self.requiredSeconds)
            if self.progress >= 1.0 {
                self.stop()
                self.onCompleted?()
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
