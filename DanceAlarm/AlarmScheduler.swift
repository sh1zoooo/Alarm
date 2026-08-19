import Foundation
import UserNotifications

enum AlarmScheduler {

    static func schedule(alarm: Alarm) {
        let center = UNUserNotificationCenter.current()
        cancel(alarm: alarm)

        let content = UNMutableNotificationContent()
        content.title = alarm.label
        content.body = "Задание: \(alarm.challenge.rawValue) — \(alarm.challenge.description)"
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive // повышает шанс пробиться через Focus/Не беспокоить без спецразрешения
        }
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.userInfo = ["alarmId": alarm.id.uuidString]

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: alarm.time)

        if alarm.repeatDays.isEmpty {
            // Разовый будильник на ближайшее срабатывание этого времени
            var triggerComps = comps
            triggerComps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("❌ Ошибка планирования будильника: \(error)")
                } else {
                    print("✅ Будильник запланирован на \(triggerComps.hour ?? -1):\(triggerComps.minute ?? -1), следующее срабатывание: \(trigger.nextTriggerDate()?.description ?? "неизвестно")")
                }
            }
        } else {
            // Повторяющийся будильник — отдельное уведомление на каждый день недели
            for weekday in alarm.repeatDays {
                var triggerComps = comps
                triggerComps.weekday = weekday
                triggerComps.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
                let identifier = "\(alarm.id.uuidString)_\(weekday)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request) { error in
                    if let error {
                        print("❌ Ошибка планирования будильника (день \(weekday)): \(error)")
                    }
                }
            }
        }
    }

    static func cancel(alarm: Alarm) {
        let center = UNUserNotificationCenter.current()
        var identifiers = [alarm.id.uuidString]
        identifiers += (1...7).map { "\(alarm.id.uuidString)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Отладочный будильник — сработает через `seconds` секунд.
    /// Полезно чтобы проверить весь пайплайн (разрешения, звук, экран задания),
    /// не дожидаясь реального времени.
    static func scheduleTestAlarm(seconds: TimeInterval = 10, challenge: ChallengeType) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Тестовый будильник"
        content.body = "Задание: \(challenge.rawValue)"
        content.sound = .default
        content.userInfo = ["alarmId": "test-alarm"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        content.userInfo = ["alarmId": "test-alarm", "testChallenge": challenge.rawValue]
        let request = UNNotificationRequest(identifier: "test-alarm", content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("❌ Тестовый будильник не запланирован: \(error)")
            } else {
                print("✅ Тестовый будильник сработает через \(seconds) сек")
            }
        }
    }

    /// Для отладки: выводит в консоль все запланированные уведомления
    static func debugPrintPending() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Запланировано уведомлений: \(requests.count)")
            for r in requests {
                if let trigger = r.trigger as? UNCalendarNotificationTrigger {
                    print("  - \(r.identifier): следующее срабатывание \(trigger.nextTriggerDate()?.description ?? "?")")
                } else if let trigger = r.trigger as? UNTimeIntervalNotificationTrigger {
                    print("  - \(r.identifier): через \(trigger.timeInterval) сек")
                }
            }
        }
    }

    /// То же самое, но результат приходит в замыкание — чтобы показать прямо в UI на экране,
    /// без необходимости смотреть консоль Xcode
    static func fetchPendingDescriptions(completion: @escaping ([String]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let lines: [String] = requests.map { r in
                if let trigger = r.trigger as? UNCalendarNotificationTrigger {
                    let date = trigger.nextTriggerDate()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd.MM HH:mm:ss"
                    let dateStr = date.map { formatter.string(from: $0) } ?? "неизвестно"
                    return "\(r.content.title): \(dateStr)"
                } else if let trigger = r.trigger as? UNTimeIntervalNotificationTrigger {
                    return "\(r.content.title): через \(Int(trigger.timeInterval))с"
                }
                return r.content.title
            }
            DispatchQueue.main.async {
                completion(lines)
            }
        }
    }
}
