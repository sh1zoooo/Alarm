import AVFoundation

/// Играет громкий зацикленный звук будильника, пока пользователь не выполнит задание
final class AlarmSoundPlayer {
    static let shared = AlarmSoundPlayer()
    private var player: AVAudioPlayer?

    func startLoudLoop() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            guard let url = Bundle.main.url(forResource: "alarm_sound", withExtension: "wav") else {
                print("⚠️ alarm_sound.wav не найден в бандле")
                return
            }
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.play()
        } catch {
            print("❌ Alarm sound error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Держит приложение "живым" в фоне через background audio mode (тихий зацикленный звук)
/// и каждые несколько секунд сверяет время с будильниками напрямую — это и есть
/// "настоящий" механизм звонка, а не просто System-уведомление.
/// ВАЖНО: работает только пока процесс жив (приложение свёрнуто, НЕ force-quit'нуто).
/// Если пользователь смахнёт приложение из списка недавних — iOS убьёт процесс,
/// и разбудить его сможет только тап по резервному локальному уведомлению.
final class BackgroundAudioKeeper {
    static let shared = BackgroundAudioKeeper()
    private var silentPlayer: AVAudioPlayer?
    private var watchTimer: Timer?

    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Background audio session error: \(error)")
        }

        if let url = Bundle.main.url(forResource: "silence", withExtension: "wav") {
            do {
                silentPlayer = try AVAudioPlayer(contentsOf: url)
                silentPlayer?.numberOfLoops = -1
                silentPlayer?.volume = 0.01
                silentPlayer?.play()
            } catch {
                print("❌ Silent player error: \(error)")
            }
        } else {
            print("⚠️ silence.wav не найден — keep-alive может не работать в фоне")
        }

        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            AlarmManager.shared.checkForDueAlarms()
        }
        RunLoop.main.add(watchTimer!, forMode: .common)
        // сразу проверяем один раз при старте
        AlarmManager.shared.checkForDueAlarms()
    }
}
