import Foundation
import UserNotifications
import Combine

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var time: Date
    var isEnabled: Bool = true
    var challenge: ChallengeType = .dance
    var repeatDays: Set<Int> = [] // 1 = Sunday ... 7 = Saturday, пусто = один раз
    var label: String = "Будильник"
}

final class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var alarms: [Alarm] = [] {
        didSet { save() }
    }
    @Published var isRinging: Bool = false
    @Published var currentlyRingingAlarm: Alarm?
    @Published var notificationsAuthorized: Bool = true // оптимистичный дефолт, обновится асинхронно
    @Published var lastWatchdogCheck: Date? // для отладки — когда таймер последний раз проверял будильники

    private let storeKey = "dance_alarm_list"
    private var lastFiredAt: [UUID: Date] = [:]

    private init() {
        load()
        refreshAuthorizationStatus()
    }

    /// Перепроверяет реальный статус разрешения (например, если пользователь
    /// изменил его в Настройки → Уведомления, пока приложение было свёрнуто)
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        schedule(alarm)
    }

    func removeAlarm(at offsets: IndexSet) {
        for idx in offsets {
            AlarmScheduler.cancel(alarm: alarms[idx])
        }
        alarms.remove(atOffsets: offsets)
    }

    func toggle(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(of: alarm) else { return }
        alarms[idx].isEnabled.toggle()
        if alarms[idx].isEnabled {
            schedule(alarms[idx])
        } else {
            AlarmScheduler.cancel(alarm: alarms[idx])
        }
    }

    func schedule(_ alarm: Alarm) {
        AlarmScheduler.schedule(alarm: alarm)
    }

    /// Главный механизм "настоящего" будильника: вызывается фоновым таймером каждые ~15 сек
    /// (пока процесс жив благодаря background audio режиму) и сверяет текущее время
    /// со временем каждого включённого будильника. Если совпадает — запускает звук
    /// НАПРЯМУЮ, не дожидаясь тапа по уведомлению.
    func checkForDueAlarms() {
        lastWatchdogCheck = Date()
        guard !isRinging else { return } // уже звоним — не дублируем

        let now = Date()
        let calendar = Calendar.current
        let nowComps = calendar.dateComponents([.hour, .minute], from: now)

        for alarm in alarms where alarm.isEnabled {
            let alarmComps = calendar.dateComponents([.hour, .minute], from: alarm.time)
            guard nowComps.hour == alarmComps.hour, nowComps.minute == alarmComps.minute else { continue }

            if !alarm.repeatDays.isEmpty {
                let weekday = calendar.component(.weekday, from: now)
                guard alarm.repeatDays.contains(weekday) else { continue }
            }

            // защита от повторного срабатывания в течение той же минуты
            if let last = lastFiredAt[alarm.id], now.timeIntervalSince(last) < 90 { continue }
            lastFiredAt[alarm.id] = now
            fireAlarmDirectly(alarm)
            break // одновременно звоним только одним будильником
        }
    }

    private func fireAlarmDirectly(_ alarm: Alarm) {
        currentlyRingingAlarm = alarm
        isRinging = true
        AlarmSoundPlayer.shared.startLoudLoop()
        if alarm.repeatDays.isEmpty, let idx = alarms.firstIndex(of: alarm) {
            alarms[idx].isEnabled = false
        }
    }

    /// Мгновенный запуск экрана задания для отладки — без ожидания, без уведомлений
    func testChallenge(_ type: ChallengeType) {
        currentlyRingingAlarm = Alarm(time: Date(), challenge: type, label: "Тест: \(type.rawValue)")
        isRinging = true
        AlarmSoundPlayer.shared.startLoudLoop()
    }

    /// Вызывается когда сработало уведомление — показываем полноэкранный экран будильника
    func triggerRinging(userInfo: [AnyHashable: Any]) {
        let alarmId = userInfo["alarmId"] as? String ?? ""

        if alarmId == "test-alarm" {
            let challengeRaw = userInfo["testChallenge"] as? String ?? ChallengeType.dance.rawValue
            let challenge = ChallengeType(rawValue: challengeRaw) ?? .dance
            currentlyRingingAlarm = Alarm(time: Date(), challenge: challenge, label: "Тестовый будильник")
            isRinging = true
            AlarmSoundPlayer.shared.startLoudLoop()
            return
        }

        guard let alarm = alarms.first(where: { $0.id.uuidString == alarmId }) else {
            // Уведомление не найдено в списке — всё равно покажем последний известный будильник
            if let first = alarms.first {
                currentlyRingingAlarm = first
                isRinging = true
                AlarmSoundPlayer.shared.startLoudLoop()
            }
            return
        }
        currentlyRingingAlarm = alarm
        isRinging = true
        AlarmSoundPlayer.shared.startLoudLoop()
    }

    func dismissRinging() {
        isRinging = false
        currentlyRingingAlarm = nil
        AlarmSoundPlayer.shared.stop()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
    }
}
