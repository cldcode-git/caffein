import Foundation
import UserNotifications

/// Local notifications only; nothing leaves the phone.
enum ReminderService {
    private static let morningID = "caffein.morning"
    private static let weeklyID = "caffein.weekly"
    /// IDs used by builds made before the rename; removed so old reminders don't fire twice.
    private static let legacyMorningID = "vuru.morning"
    private static let legacyWeeklyID = "vuru.weekly"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func scheduleMorning(minutes: Int) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [legacyMorningID])
        let content = UNMutableNotificationContent()
        content.title = L("Günaydın")
        content.body = L("Kahveden önce 60 saniyelik sabah ölçümünü yap.")
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: morningID, content: content, trigger: trigger))
    }

    static func scheduleWeekly() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [legacyWeeklyID])
        let content = UNMutableNotificationContent()
        content.title = L("Haftalık özetin hazır")
        content.body = L("Kafein, uyku ve gerginlik haftana bir göz at.")
        content.sound = .default
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 19
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: weeklyID, content: content, trigger: trigger))
    }

    static func cancelMorning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [morningID, legacyMorningID])
    }

    static func cancelWeekly() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyID, legacyWeeklyID])
    }
}
