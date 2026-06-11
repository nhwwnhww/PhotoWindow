import Foundation
import UserNotifications

protocol NotificationServicing {
    func requestAuthorization() async -> Bool
    func schedule(notification: NotificationItem) async throws
    func cancel(notificationId: UUID)
}

final class NotificationService: NotificationServicing {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func schedule(notification: NotificationItem) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let secondsUntilTrigger = max(notification.triggerTime.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilTrigger, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancel(notificationId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
    }
}
