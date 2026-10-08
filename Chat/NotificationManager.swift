import UIKit
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            return false
        }
    }

    @MainActor
    static func notifyResponseReady(chatTitle: String) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.responseReady
        content.body = "\(chatTitle): \(L10n.responseReadyBody)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "response-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
