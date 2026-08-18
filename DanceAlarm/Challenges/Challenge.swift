import Foundation
import SwiftUI

/// Тип задания, которое нужно выполнить, чтобы выключить будильник
enum ChallengeType: String, CaseIterable, Identifiable, Codable {
    case dance = "Танец"
    case toiletCamera = "Покажи унитаз"
    case shake = "Тряска телефона"
    case math = "Математика"
    case qrScan = "Скан QR-кода"
    case steps = "Шаги"
    case simonSays = "Simon Says"
    case typing = "Напечатай фразу"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dance: return "figure.dance"
        case .toiletCamera: return "camera.fill"
        case .shake: return "iphone.gen3.radiowaves.left.and.right"
        case .math: return "function"
        case .qrScan: return "qrcode.viewfinder"
        case .steps: return "figure.walk"
        case .simonSays: return "square.grid.2x2.fill"
        case .typing: return "keyboard"
        }
    }

    var description: String {
        switch self {
        case .dance: return "Танцуй перед камерой телефона 8 секунд без остановки"
        case .toiletCamera: return "Наведи камеру на унитаз, чтобы выключить будильник"
        case .shake: return "Потряси телефон нужное количество раз"
        case .math: return "Реши 3 примера подряд без ошибок"
        case .qrScan: return "Найди и отсканируй QR-код (например, в ванной)"
        case .steps: return "Пройди 20 шагов с телефоном в руке"
        case .simonSays: return "Повтори последовательность нажатий"
        case .typing: return "Напечатай фразу без единой опечатки"
        }
    }
}

/// Общий протокол для экрана-задания. У каждого Challenge-view есть колбэк onCompleted.
protocol ChallengeCompletable {
    var onCompleted: () -> Void { get }
}
