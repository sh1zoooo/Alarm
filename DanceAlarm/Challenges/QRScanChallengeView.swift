import SwiftUI
import AVFoundation

/// Пользователь заранее задаёт "секретный" текст QR-кода (например, наклеивает свой QR в ванной).
/// Хранится в UserDefaults под ключом "expected_qr_value".
struct QRScanChallengeView: View {
    let onCompleted: () -> Void
    @StateObject private var scanner = QRScannerController()

    var body: some View {
        ZStack {
            CameraPreview(session: scanner.session)
                .ignoresSafeArea()
            VStack {
                Spacer()
                Text(scanner.statusText)
                    .foregroundColor(.white)
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            scanner.onCompleted = onCompleted
            scanner.start()
        }
        .onDisappear { scanner.stop() }
    }
}

final class QRScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    @Published var statusText = "Наведи камеру на QR-код"
    var onCompleted: (() -> Void)?

    private var expectedValue: String {
        UserDefaults.standard.string(forKey: "expected_qr_value") ?? ""
    }

    func start() {
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }

        if expectedValue.isEmpty || value == expectedValue {
            statusText = "QR найден ✅"
            onCompleted?()
        } else {
            statusText = "Это не тот QR-код"
        }
    }
}
