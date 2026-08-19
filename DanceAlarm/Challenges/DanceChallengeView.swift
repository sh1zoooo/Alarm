import SwiftUI
import AVFoundation
import Vision

/// Танец с фронтальной камерой: Vision отслеживает ключевые точки тела
/// (запястья, локти, колени, лодыжки, торс) и считает, насколько активно
/// человек двигается. Нужно набрать `requiredSeconds` активного движения подряд.
struct DanceChallengeView: View {
    let onCompleted: () -> Void
    private let requiredSeconds: Double = 8.0

    @StateObject private var tracker = DanceBodyTracker()

    var body: some View {
        ZStack {
            CameraPreview(session: tracker.session)
                .ignoresSafeArea()

            SkeletonOverlay(points: tracker.currentPoints)
                .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 10)
                            .frame(width: 140, height: 140)
                        Circle()
                            .trim(from: 0, to: tracker.progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: tracker.progress)
                        Text("\(Int(tracker.progress * requiredSeconds))s")
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }
                    Text(tracker.statusText)
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            tracker.requiredSeconds = requiredSeconds
            tracker.onCompleted = onCompleted
            tracker.start()
        }
        .onDisappear {
            tracker.stop()
        }
    }
}

/// Отслеживает позу человека через фронтальную камеру и Vision Body Pose Detection.
final class DanceBodyTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "dance.body.tracker")

    @Published var progress: Double = 0
    @Published var statusText: String = "Ищу тебя в кадре..."
    @Published var currentPoints: [CGPoint] = [] // нормализованные точки (0..1) для отрисовки скелета

    var requiredSeconds: Double = 8.0
    var onCompleted: (() -> Void)?

    private var accumulatedTime: Double = 0
    private var lastFrameTime: Date?
    private var previousJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    private let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .leftWrist, .rightWrist, .leftElbow, .rightElbow,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
        .neck, .root
    ]
    // порог суммарного нормализованного смещения точек между кадрами, который считаем "движением"
    private let movementThreshold: CGFloat = 0.12

    func start() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        session.commitConfiguration()
        lastFrameTime = Date()
        queue.async { self.session.startRunning() }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            DispatchQueue.main.async {
                self.statusText = "Не вижу тебя — встань перед камерой"
                self.currentPoints = []
            }
            return
        }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for jointName in trackedJoints {
            if let point = try? observation.recognizedPoint(jointName), point.confidence > 0.3 {
                joints[jointName] = point.location
            }
        }

        // считаем суммарное смещение относительно предыдущего кадра по всем совпавшим точкам
        var totalMovement: CGFloat = 0
        var matchedCount = 0
        for (name, point) in joints {
            if let prev = previousJoints[name] {
                let dx = point.x - prev.x
                let dy = point.y - prev.y
                totalMovement += sqrt(dx * dx + dy * dy)
                matchedCount += 1
            }
        }
        previousJoints = joints

        let now = Date()
        let dt = now.timeIntervalSince(lastFrameTime ?? now)
        lastFrameTime = now

        let isMoving = matchedCount > 0 && totalMovement > movementThreshold

        DispatchQueue.main.async {
            self.currentPoints = joints.values.map { CGPoint(x: $0.x, y: 1 - $0.y) } // Vision Y снизу-вверх -> переворачиваем под SwiftUI

            if joints.isEmpty {
                self.statusText = "Не вижу тебя — встань перед камерой"
                return
            }

            if isMoving {
                self.statusText = "🔥 Танцуй, так держать!"
                self.accumulatedTime += dt
            } else {
                self.statusText = "Двигайся активнее — руки, ноги, всё тело!"
                self.accumulatedTime = max(0, self.accumulatedTime - dt * 2)
            }

            self.progress = min(1.0, self.accumulatedTime / self.requiredSeconds)
            if self.progress >= 1.0 {
                self.stop()
                self.onCompleted?()
            }
        }
    }
}

/// Рисует скелет-точки поверх камеры для наглядной обратной связи
struct SkeletonOverlay: View {
    let points: [CGPoint] // нормализованные 0..1 координаты

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<points.count, id: \.self) { i in
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .position(
                            x: (1 - points[i].x) * geo.size.width, // доп. зеркалим X, т.к. превью тоже зеркалим
                            y: points[i].y * geo.size.height
                        )
                        .shadow(color: .green, radius: 4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
