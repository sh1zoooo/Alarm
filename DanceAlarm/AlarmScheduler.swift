import Foundation
import UserNotifications

enum AlarmScheduler {

    static func schedule(alarm: Alarm) {
        let center = UNUserNotificationCenter.current()
        cancel(alarm: alarm)

        let content = UNMutableNotificationContent()
        content.title = alarm.label
        content.body = "Задание: \(alarm.challenge.rawValue) — \(alarm.challenge.description)"
        content.sound = .defaultCritical
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
            center.add(request)
        } else {
            // Повторяющийся будильник — отдельное уведомление на каждый день недели
            for weekday in alarm.repeatDays {
                var triggerComps = comps
                triggerComps.weekday = weekday
                triggerComps.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
                let identifier = "\(alarm.id.uuidString)_\(weekday)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    static func cancel(alarm: Alarm) {
        let center = UNUserNotificationCenter.current()
        var identifiers = [alarm.id.uuidString]
        identifiers += (1...7).map { "\(alarm.id.uuidString)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
