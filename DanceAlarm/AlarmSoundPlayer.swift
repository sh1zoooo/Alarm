import AVFoundation

/// Играет громкий зацикленный звук будильника, пока пользователь не выполнит задание
final class AlarmSoundPlayer {
    static let shared = AlarmSoundPlayer()
    private var player: AVAudioPlayer?

    func startLoudLoop() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            guard let url = Bundle.main.url(forResource: "alarm_sound", withExtension: "caf") else { return }
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 1.0
            player?.play()
        } catch {
            print("Alarm sound error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Держит приложение "живым" в фоне через background audio mode с тишиной,
/// чтобы таймеры/уведомления срабатывали надёжнее, как это делает Alarmy.
/// ВАЖНО: в Info.plist должен быть добавлен Background Mode "Audio, AirPlay, and Picture in Picture".
final class BackgroundAudioKeeper {
    static let shared = BackgroundAudioKeeper()
    private var silentPlayer: AVAudioPlayer?

    func start() {
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "caf") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1
            silentPlayer?.volume = 0.01
            silentPlayer?.play()
        } catch {
            print("Background keeper error: \(error)")
        }
    }
}
