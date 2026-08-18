import SwiftUI
import UserNotifications

@main
struct DanceAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var alarmManager = AlarmManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .fullScreenCover(isPresented: $alarmManager.isRinging) {
                    AlarmRingingView()
                        .environmentObject(alarmManager)
                }
        }
    }
}

/// AppDelegate нужен чтобы:
/// 1) запросить разрешения на уведомления
/// 2) ловить срабатывание уведомления, даже если приложение открыто (foreground)
/// 3) настроить фоновый аудио-сеанс, который держит приложение "живым",
///    как это делает Alarmy — без этого iOS не даст надёжно разбудить пользователя.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        BackgroundAudioKeeper.shared.start()
        return true
    }

    // Показываем алерт, даже если приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AlarmManager.shared.triggerRinging(alarmId: notification.request.identifier)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        AlarmManager.shared.triggerRinging(alarmId: response.notification.request.identifier)
        completionHandler()
    }
}
