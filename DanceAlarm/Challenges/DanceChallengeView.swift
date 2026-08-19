import SwiftUI
import AVFoundation
import Vision

/// Танец с фронтальной камерой: Vision отслеживает ключевые точки тела.
/// Засчитывается движение ЛЮБОЙ отслеживаемой части тела (не нужно двигать всем сразу).
struct DanceChallengeView: View {
    let onCompleted: () -> Void
    private let requiredSeconds: Double = 8.0

    @StateObject private var tracker = DanceBodyTracker()

    var body: some View {
        ZStack {
            CameraPreview(session: tracker.session)
                .ignoresSafeArea()

            StickFigureOverlay(joints: tracker.currentJoints)
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
    /// Нормализованные (0..1, уже во view-координатах: X зеркалим, Y переворачиваем) точки суставов
    @Published var currentJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    var requiredSeconds: Double = 8.0
    var onCompleted: (() -> Void)?

    private var accumulatedTime: Double = 0
    private var lastFrameTime: Date?
    private var previousJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    private let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .leftWrist, .rightWrist, .leftElbow, .rightElbow, .leftShoulder, .rightShoulder,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .leftHip, .rightHip,
        .neck, .root
    ]
    /// Порог смещения ОДНОЙ точки между кадрами (в нормализованных координатах),
    /// после которого считаем что человек двигается. Специально низкий и берём МАКСИМУМ,
    /// а не сумму по всем точкам — чтобы засчитывалось движение даже одной рукой/ногой.
    private let perJointThreshold: CGFloat = 0.012

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
                self.currentJoints = [:]
            }
            return
        }

        var rawJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for jointName in trackedJoints {
            if let point = try? observation.recognizedPoint(jointName), point.confidence > 0.3 {
                rawJoints[jointName] = point.location
            }
        }

        // максимальное смещение среди точек, совпавших и в этом, и в предыдущем кадре
        var maxMovement: CGFloat = 0
        var matchedCount = 0
        for (name, point) in rawJoints {
            if let prev = previousJoints[name] {
                let dx = point.x - prev.x
                let dy = point.y - prev.y
                let delta = sqrt(dx * dx + dy * dy)
                maxMovement = max(maxMovement, delta)
                matchedCount += 1
            }
        }
        previousJoints = rawJoints

        let now = Date()
        let dt = now.timeIntervalSince(lastFrameTime ?? now)
        lastFrameTime = now

        let isMoving = matchedCount > 0 && maxMovement > perJointThreshold

        // Vision: (0,0) внизу-слева. View: (0,0) вверху-слева. Плюс зеркалим X — фронталка уже
        // отзеркалена системным preview layer, точки должны совпасть с картинкой.
        let viewJoints = Dictionary(uniqueKeysWithValues: rawJoints.map { name, pt in
            (name, CGPoint(x: 1 - pt.x, y: 1 - pt.y))
        })

        DispatchQueue.main.async {
            self.currentJoints = viewJoints

            if rawJoints.isEmpty {
                self.statusText = "Не вижу тебя — встань перед камерой"
                return
            }

            if isMoving {
                self.statusText = "🔥 Танцуй, так держать!"
                self.accumulatedTime += dt
            } else {
                self.statusText = "Двигайся активнее — руки, ноги, всё тело!"
                self.accumulatedTime = max(0, self.accumulatedTime - dt * 1.5)
            }

            self.progress = min(1.0, self.accumulatedTime / self.requiredSeconds)
            if self.progress >= 1.0 {
                self.stop()
                self.onCompleted?()
            }
        }
    }
}

/// Рисует белый скелет-фигурку поверх камеры, в духе простого рисунка человечка:
/// прямоугольный торс, тонкие линии рук/ног, скруглённые "варежки" на кистях/ступнях.
struct StickFigureOverlay: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { context, _ in
                func p(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                    guard let n = joints[name] else { return nil }
                    return CGPoint(x: n.x * size.width, y: n.y * size.height)
                }

                context.stroke(
                    Path { path in
                        // торс — четырёхугольник между плечами и бёдрами
                        if let ls = p(.leftShoulder), let rs = p(.rightShoulder),
                           let lh = p(.leftHip), let rh = p(.rightHip) {
                            path.move(to: ls)
                            path.addLine(to: rs)
                            path.addLine(to: rh)
                            path.addLine(to: lh)
                            path.closeSubpath()
                        }
                    },
                    with: .color(.white), lineWidth: 6
                )

                func limb(_ a: VNHumanBodyPoseObservation.JointName, _ b: VNHumanBodyPoseObservation.JointName, _ c: VNHumanBodyPoseObservation.JointName) {
                    var path = Path()
                    if let pa = p(a) {
                        path.move(to: pa)
                        if let pb = p(b) {
                            path.addLine(to: pb)
                            if let pc = p(c) {
                                path.addLine(to: pc)
                            }
                        }
                    }
                    context.stroke(path, with: .color(.white), lineWidth: 6)
                }

                // руки: плечо -> локоть -> запястье
                limb(.leftShoulder, .leftElbow, .leftWrist)
                limb(.rightShoulder, .rightElbow, .rightWrist)
                // ноги: бедро -> колено -> лодыжка
                limb(.leftHip, .leftKnee, .leftAnkle)
                limb(.rightHip, .rightKnee, .rightAnkle)

                // скруглённые "варежки" на кистях и ступнях, как на рисунке
                for name in [VNHumanBodyPoseObservation.JointName.leftWrist, .rightWrist, .leftAnkle, .rightAnkle] {
                    if let pt = p(name) {
                        let rect = CGRect(x: pt.x - 22, y: pt.y - 18, width: 44, height: 36)
                        context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(.white), lineWidth: 5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
