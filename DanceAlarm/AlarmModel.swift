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

    private let storeKey = "dance_alarm_list"

    private init() {
        load()
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

    /// Вызывается когда сработало уведомление — показываем полноэкранный экран будильника
    func triggerRinging(alarmId: String) {
        guard let alarm = alarms.first(where: { $0.id.uuidString == alarmId }) else {
            // Уведомление не найдено в списке — всё равно покажем последний известный будильник
            if let first = alarms.first {
                currentlyRingingAlarm = first
                isRinging = true
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
