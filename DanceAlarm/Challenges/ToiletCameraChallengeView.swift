import SwiftUI
import AVFoundation
import Vision

/// Открывает камеру и через Vision (VNClassifyImageRequest, встроенная модель Apple)
/// проверяет, есть ли в кадре что-то похожее на туалет/сантехнику среди топ-меток.
struct ToiletCameraChallengeView: View {
    let onCompleted: () -> Void
    @StateObject private var vision = ToiletVisionController()

    var body: some View {
        ZStack {
            CameraPreview(session: vision.session)
                .ignoresSafeArea()
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("Наведи камеру на унитаз 🚽")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(vision.statusText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    if vision.isChecking {
                        ProgressView().tint(.white)
                    }
                }
                .padding()
                .background(.black.opacity(0.6))
                .cornerRadius(16)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            vision.onCompleted = onCompleted
            vision.start()
        }
        .onDisappear {
            vision.stop()
        }
    }
}

final class ToiletVisionController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "toilet.vision.queue")

    @Published var statusText: String = "Ищу унитаз в кадре..."
    @Published var isChecking: Bool = false

    var onCompleted: (() -> Void)?
    private var lastCheck = Date.distantPast
    private var confirmedFrames = 0
    // Ключевые слова из встроенного классификатора Apple, которые соответствуют унитазу/ванной
    private let targetKeywords = ["toilet", "bathroom", "lavatory", "plumbing fixture", "bidet", "flush"]

    func start() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        queue.async { self.session.startRunning() }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Проверяем не чаще раза в секунду, чтобы не грузить CPU
        guard Date().timeIntervalSince(lastCheck) > 1.0 else { return }
        lastCheck = Date()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNClassifyImageRequest { [weak self] request, error in
            guard let self else { return }
            guard let results = request.results as? [VNClassificationObservation] else { return }
            let topLabels = results.prefix(10).map { $0.identifier.lowercased() }
            let found = topLabels.contains { label in
                self.targetKeywords.contains { label.contains($0) }
            }
            DispatchQueue.main.async {
                if found {
                    self.confirmedFrames += 1
                    self.statusText = "Похоже на унитаз! (\(self.confirmedFrames)/2)"
                    if self.confirmedFrames >= 2 { // 2 подряд успешных кадра — защита от случайного срабатывания
                        self.statusText = "Готово! ✅"
                        self.onCompleted?()
                    }
                } else {
                    self.confirmedFrames = 0
                    self.statusText = "Не вижу унитаз, наведи точнее"
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])
    }
}

/// UIViewRepresentable-обёртка для показа превью камеры
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
