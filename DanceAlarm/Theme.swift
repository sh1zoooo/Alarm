import SwiftUI

/// Единая палитра "Разбудильника" — та же, что в иконке приложения.
/// Коралловый — основной акцент (энергия, тревога будильника),
/// лаймовый — редкий акцент для успеха/прогресса.
enum Theme {
    static let background = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x10 / 255)
    static let surface = Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x1D / 255)
    static let coral = Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x5C / 255)
    static let coralDeep = Color(red: 0xD6 / 255, green: 0x20 / 255, blue: 0x4A / 255)
    static let lime = Color(red: 0xE8 / 255, green: 0xFF / 255, blue: 0x6B / 255)
    static let textPrimary = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let textSecondary = Color.white.opacity(0.6)

    static let ringingGradient = LinearGradient(
        colors: [background, coralDeep],
        startPoint: .top, endPoint: .bottom
    )
}
